$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$source=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'assets\privacydesk-logo-v1.png'))
try {
    $frames=@()
    foreach($size in @(256,64,48,32,16)) {
        $bitmap=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $graphics=[Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([Drawing.Color]::Transparent)
            $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.DrawImage($source,0,0,$size,$size)
            $stream=[IO.MemoryStream]::new()
            try {$bitmap.Save($stream,[Drawing.Imaging.ImageFormat]::Png);$frames+=@{Size=$size;Bytes=$stream.ToArray()}}finally{$stream.Dispose()}
        } finally {$graphics.Dispose();$bitmap.Dispose()}
    }
    $output=[IO.File]::Create((Join-Path $PSScriptRoot 'assets\privacydesk.ico'))
    $writer=[IO.BinaryWriter]::new($output)
    try {
        $writer.Write([uint16]0);$writer.Write([uint16]1);$writer.Write([uint16]$frames.Count)
        $offset=6+16*$frames.Count
        foreach($frame in $frames){
            $dimension=if($frame.Size -eq 256){0}else{$frame.Size}
            $writer.Write([byte]$dimension);$writer.Write([byte]$dimension);$writer.Write([byte]0);$writer.Write([byte]0)
            $writer.Write([uint16]1);$writer.Write([uint16]32);$writer.Write([uint32]$frame.Bytes.Length);$writer.Write([uint32]$offset)
            $offset+=$frame.Bytes.Length
        }
        foreach($frame in $frames){$writer.Write([byte[]]$frame.Bytes)}
    }finally{$writer.Dispose();$output.Dispose()}
}finally{$source.Dispose()}
