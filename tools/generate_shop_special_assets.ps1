param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
)

Add-Type -AssemblyName System.Drawing

$OutDir = Join-Path $Root "project/assets/ui/shop"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function ColorFromHex([string]$hex, [int]$alpha = 255) {
    $hex = $hex.TrimStart("#")
    return [System.Drawing.Color]::FromArgb(
        $alpha,
        [Convert]::ToInt32($hex.Substring(0, 2), 16),
        [Convert]::ToInt32($hex.Substring(2, 2), 16),
        [Convert]::ToInt32($hex.Substring(4, 2), 16)
    )
}

function ChamferPoints([int]$x, [int]$y, [int]$w, [int]$h, [int]$cut) {
    return [System.Drawing.Point[]]@(
        [System.Drawing.Point]::new($x + $cut, $y),
        [System.Drawing.Point]::new($x + $w - $cut, $y),
        [System.Drawing.Point]::new($x + $w, $y + $cut),
        [System.Drawing.Point]::new($x + $w, $y + $h - $cut),
        [System.Drawing.Point]::new($x + $w - $cut, $y + $h),
        [System.Drawing.Point]::new($x + $cut, $y + $h),
        [System.Drawing.Point]::new($x, $y + $h - $cut),
        [System.Drawing.Point]::new($x, $y + $cut)
    )
}

function DrawPanel(
    [string]$Name,
    [int]$Width,
    [int]$Height,
    [string]$Fill,
    [string]$Border,
    [int]$Cut = 18,
    [int]$BorderWidth = 5
) {
    $bmp = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $shadow = ChamferPoints 12 14 ($Width - 20) ($Height - 22) $Cut
    $shadowBrush = [System.Drawing.SolidBrush]::new((ColorFromHex "#000000" 125))
    $g.FillPolygon($shadowBrush, $shadow)

    $points = ChamferPoints 6 6 ($Width - 18) ($Height - 18) $Cut
    $fillBrush = [System.Drawing.SolidBrush]::new((ColorFromHex $Fill 238))
    $outerPen = [System.Drawing.Pen]::new((ColorFromHex "#070407" 255), [Math]::Max(6, $BorderWidth + 3))
    $innerPen = [System.Drawing.Pen]::new((ColorFromHex $Border 245), $BorderWidth)
    $hiPen = [System.Drawing.Pen]::new((ColorFromHex "#ffd56d" 80), 2)
    $darkPen = [System.Drawing.Pen]::new((ColorFromHex "#000000" 115), 2)

    $g.FillPolygon($fillBrush, $points)
    $g.DrawPolygon($outerPen, $points)
    $g.DrawPolygon($innerPen, $points)
    $g.DrawLine($hiPen, $Cut + 18, 15, $Width - $Cut - 34, 15)
    $g.DrawLine($darkPen, $Cut + 12, $Height - 19, $Width - $Cut - 28, $Height - 19)

    $texturePen = [System.Drawing.Pen]::new((ColorFromHex "#000000" 35), 1)
    for ($i = 0; $i -lt 18; $i++) {
        $x = 12 + (($i * 47) % [Math]::Max(13, $Width - 24))
        $g.DrawLine($texturePen, $x, 18, [Math]::Min($Width - 16, $x + 52), $Height - 20)
    }

    $path = Join-Path $OutDir $Name
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $texturePen.Dispose()
    $darkPen.Dispose()
    $hiPen.Dispose()
    $innerPen.Dispose()
    $outerPen.Dispose()
    $fillBrush.Dispose()
    $shadowBrush.Dispose()
    $g.Dispose()
    $bmp.Dispose()
}

DrawPanel "shop_status_bar_dark.png" 520 76 "#101015" "#352c32" 18 4
DrawPanel "shop_requirement_panel_red.png" 420 182 "#191014" "#bc1f32" 20 5
DrawPanel "shop_requirement_panel_teal.png" 420 182 "#0d1b1d" "#138b83" 20 5
DrawPanel "shop_artifact_frame_red.png" 170 126 "#2b1115" "#bd2032" 16 5
DrawPanel "shop_artifact_frame_teal.png" 170 126 "#062529" "#12958c" 16 5
DrawPanel "shop_artifact_frame_purple.png" 170 126 "#21172f" "#7442a4" 16 5
DrawPanel "shop_price_plate_dark.png" 210 54 "#111015" "#3e353b" 12 4
DrawPanel "shop_count_badge_dark.png" 54 54 "#101015" "#3e353b" 8 3
DrawPanel "shop_stat_row_dark.png" 330 52 "#111015" "#3e353b" 10 4
DrawPanel "shop_nameplate_red.png" 330 64 "#7f111d" "#d12735" 14 5

Write-Host "Generated shop special assets in $OutDir"
