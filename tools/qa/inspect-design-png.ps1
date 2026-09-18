[CmdletBinding()]
param([Parameter(Mandatory)][string[]]$Path)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$results=foreach($source in $Path) {
  $resolved=(Resolve-Path -LiteralPath $source).Path
  $bitmap=[Drawing.Bitmap]::new($resolved)
  try {
    $width=$bitmap.Width; $height=$bitmap.Height
    $rect=[Drawing.Rectangle]::new(0,0,$width,$height)
    $data=$bitmap.LockBits($rect,[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
      $row=[byte[]]::new($width*4)
      $transparent=0L; $partial=0L; $opaque=0L
      $minAlpha=255; $maxAlpha=0; $nearOpaque=0L
      $minX=$width; $minY=$height; $maxX=-1; $maxY=-1
      $coreMinX=$width; $coreMinY=$height; $coreMaxX=-1; $coreMaxY=-1
      for($y=0;$y -lt $height;$y++) {
        [Runtime.InteropServices.Marshal]::Copy([IntPtr]::Add($data.Scan0,$y*$data.Stride),$row,0,$row.Length)
        for($x=0;$x -lt $width;$x++) {
          $alpha=$row[$x*4+3]
          $minAlpha=[Math]::Min($minAlpha,$alpha); $maxAlpha=[Math]::Max($maxAlpha,$alpha)
          if($alpha -ge 250 -and $alpha -le 254) { $nearOpaque++ }
          if($alpha -ge 128) {
            $coreMinX=[Math]::Min($coreMinX,$x); $coreMaxX=[Math]::Max($coreMaxX,$x)
            $coreMinY=[Math]::Min($coreMinY,$y); $coreMaxY=[Math]::Max($coreMaxY,$y)
          }
          if($alpha -eq 0) { $transparent++ } else {
            if($alpha -eq 255) { $opaque++ } else { $partial++ }
            $minX=[Math]::Min($minX,$x); $maxX=[Math]::Max($maxX,$x)
            $minY=[Math]::Min($minY,$y); $maxY=[Math]::Max($maxY,$y)
          }
        }
      }
      $bounds=if($maxX -lt 0) { $null } else { @{x=$minX;y=$minY;width=$maxX-$minX+1;height=$maxY-$minY+1} }
      $coreBounds=if($coreMaxX -lt 0) { $null } else { @{x=$coreMinX;y=$coreMinY;width=$coreMaxX-$coreMinX+1;height=$coreMaxY-$coreMinY+1} }
      [ordered]@{path=$resolved;sha256=(Get-FileHash -LiteralPath $resolved -Algorithm SHA256).Hash;width=$width;height=$height;pixel_format=$bitmap.PixelFormat.ToString();alpha_min=$minAlpha;alpha_max=$maxAlpha;transparent_pixels=$transparent;partial_alpha_pixels=$partial;near_opaque_250_254_pixels=$nearOpaque;opaque_pixels=$opaque;nonzero_alpha_bounds=$bounds;alpha_ge128_bounds=$coreBounds;has_transparent_and_visible_pixels=($transparent -gt 0 -and ($opaque+$partial) -gt 0);scope='Decoded alpha statistics; no raster edits, no semantic matte-quality guarantee'}
    } finally { $bitmap.UnlockBits($data) }
  } finally { $bitmap.Dispose() }
}
@($results) | ConvertTo-Json -Depth 5
