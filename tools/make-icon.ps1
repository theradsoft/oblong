param([string]$OutIco, [string]$PreviewPng)
Add-Type -AssemblyName System.Drawing

function C($hex) { [Drawing.ColorTranslator]::FromHtml($hex) }
$back  = C '#1F2937'
$tileL = C '#3B82F6'
$tileT = C '#38BDF8'
$tileB = C '#FBBF24'

function RoundRect($g, $brush, $x, $y, $w, $h, $r) {
    if ($r -lt 1) { $g.FillRectangle($brush, $x, $y, $w, $h); return }
    $d = 2 * $r
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure()
    $g.FillPath($brush, $p)
    $p.Dispose()
}

function Render([int]$s) {
    $bmp = New-Object Drawing.Bitmap $s, $s, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.Clear([Drawing.Color]::Transparent)
    $g.PixelOffsetMode = 'Half'
    $g.SmoothingMode = 'AntiAlias'

    # Backing "screen": wider than tall (an oblong), centred
    $x0 = [Math]::Floor($s * 0.03); $x1 = $s - $x0
    $bh = [Math]::Round(($x1 - $x0) / 1.4)
    $y0 = [Math]::Floor(($s - $bh) / 2); $y1 = $y0 + $bh
    $r  = [Math]::Max(2, [Math]::Round($s * 0.11))
    RoundRect $g (New-Object Drawing.SolidBrush $back) $x0 $y0 ($x1 - $x0) ($y1 - $y0) $r

    # Tiles: 2/3 left, two stacked 1/3 on the right, pixel-snapped
    $pad = [Math]::Max(1, [Math]::Round($s * 0.07))
    $gap = [Math]::Max(1, [Math]::Round($s * 0.05))
    $ix0 = $x0 + $pad; $ix1 = $x1 - $pad; $iy0 = $y0 + $pad; $iy1 = $y1 - $pad
    $lw = [Math]::Round(($ix1 - $ix0 - $gap) * 2 / 3)
    $rx = $ix0 + $lw + $gap
    $th = [Math]::Floor(($iy1 - $iy0 - $gap) / 2)
    $tr = if ($s -ge 40) { [Math]::Round($s * 0.035) } else { 0 }
    if ($tr -eq 0) { $g.SmoothingMode = 'None' }
    RoundRect $g (New-Object Drawing.SolidBrush $tileL) $ix0 $iy0 $lw ($iy1 - $iy0) $tr
    RoundRect $g (New-Object Drawing.SolidBrush $tileT) $rx $iy0 ($ix1 - $rx) $th $tr
    RoundRect $g (New-Object Drawing.SolidBrush $tileB) $rx ($iy0 + $th + $gap) ($ix1 - $rx) ($iy1 - $iy0 - $th - $gap) $tr
    $g.Dispose()
    return $bmp
}

# 32-bit DIB entry (BITMAPINFOHEADER + bottom-up BGRA + empty AND mask)
function DibBytes($bmp) {
    $s = $bmp.Width
    $rect = New-Object Drawing.Rectangle 0, 0, $s, $s
    $bd = $bmp.LockBits($rect, 'ReadOnly', ([Drawing.Imaging.PixelFormat]::Format32bppArgb))
    $raw = New-Object byte[] ($bd.Stride * $s)
    [Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $raw, 0, $raw.Length)
    $bmp.UnlockBits($bd)
    $maskRow = [Math]::Floor(($s + 31) / 32) * 4
    $ms = New-Object IO.MemoryStream
    $w = New-Object IO.BinaryWriter $ms
    $w.Write([int]40); $w.Write([int]$s); $w.Write([int]($s * 2)); $w.Write([int16]1); $w.Write([int16]32)
    $w.Write([int]0); $w.Write([int]($s * $s * 4 + $maskRow * $s)); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0); $w.Write([int]0)
    for ($y = $s - 1; $y -ge 0; $y--) { $w.Write($raw, $y * $bd.Stride, $s * 4) }
    $w.Write((New-Object byte[] ($maskRow * $s)))
    $w.Flush()
    return ,$ms.ToArray()
}

function PngBytes($bmp) {
    $ms = New-Object IO.MemoryStream
    $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    return ,$ms.ToArray()
}

$sizes = 16, 20, 24, 32, 40, 48, 64, 256
$images = @()
foreach ($s in $sizes) {
    $b = Render $s
    $data = if ($s -eq 256) { PngBytes $b } else { DibBytes $b }
    $images += [pscustomobject]@{ Size = $s; Data = $data; Bmp = $b }
}

# ICO container
$fs = [IO.File]::Create($OutIco)
$w = New-Object IO.BinaryWriter $fs
$w.Write([int16]0); $w.Write([int16]1); $w.Write([int16]$images.Count)
$offset = 6 + 16 * $images.Count
foreach ($im in $images) {
    $dim = if ($im.Size -ge 256) { 0 } else { $im.Size }
    $w.Write([byte]$dim); $w.Write([byte]$dim); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([int16]1); $w.Write([int16]32); $w.Write([int]$im.Data.Length); $w.Write([int]$offset)
    $offset += $im.Data.Length
}
foreach ($im in $images) { $w.Write($im.Data) }
$w.Close()

# Preview sheet: each size at 1x and enlarged (nearest neighbour), on light and dark
$small = $images | Where-Object { $_.Size -le 64 }
$scale = 4
[int]$W = 320
foreach ($im in $small) { $W += [int]$im.Size * $scale + 24 }
[int]$H = 2 * (64 * $scale + 120)
$sheet = New-Object Drawing.Bitmap $W, $H
$g = [Drawing.Graphics]::FromImage($sheet)
$g.InterpolationMode = 'NearestNeighbor'; $g.PixelOffsetMode = 'Half'
$bgs = @((C '#F3F4F6'), (C '#202020'))
for ($row = 0; $row -lt 2; $row++) {
    $top = $row * ($H / 2)
    $g.FillRectangle((New-Object Drawing.SolidBrush $bgs[$row]), 0, $top, $W, $H / 2)
    $x = 20
    foreach ($im in $small) {
        $g.DrawImage($im.Bmp, $x, $top + 20, $im.Size, $im.Size)
        $g.DrawImage($im.Bmp, $x, $top + 90, $im.Size * $scale, $im.Size * $scale)
        $x += $im.Size * $scale + 24
    }
    $big = ($images | Where-Object { $_.Size -eq 256 }).Bmp
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.DrawImage($big, $x, $top + 20, 256, 256)
    $g.InterpolationMode = 'NearestNeighbor'
}
$g.Dispose()
$sheet.Save($PreviewPng, [Drawing.Imaging.ImageFormat]::Png)
"ico bytes: $((Get-Item $OutIco).Length)"
