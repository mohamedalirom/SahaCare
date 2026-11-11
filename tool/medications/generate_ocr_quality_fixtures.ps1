Add-Type -AssemblyName System.Drawing
$root = Join-Path (Get-Location) 'test/fixtures/medication_ocr'
$definitions = @(
 @{Name='printed';Font='Arial';Size=32;Faded=$false},
 @{Name='printed-shadow';Font='Arial';Size=24;Faded=$true},
 @{Name='handwriting-print';Font='Segoe Print';Size=30;Faded=$false},
 @{Name='handwriting-cursive';Font='Pristina';Size=40;Faded=$true}
)
foreach ($definition in $definitions) {
 $bitmap = [System.Drawing.Bitmap]::new(1000,550)
 $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
 $graphics.Clear([System.Drawing.Color]::White)
 $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
 if ($definition.Faded) {
  $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new([System.Drawing.Point]::new(0,0),[System.Drawing.Point]::new(1000,0),[System.Drawing.Color]::FromArgb(170,170,170),[System.Drawing.Color]::White)
  $graphics.FillRectangle($brush,0,0,1000,550);$brush.Dispose()
 }
 $font = [System.Drawing.Font]::new($definition.Font,[single]$definition.Size,[System.Drawing.FontStyle]::Regular,[System.Drawing.GraphicsUnit]::Pixel)
 $ink = [System.Drawing.SolidBrush]::new($(if ($definition.Faded) {[System.Drawing.Color]::FromArgb(120,120,120)}else{[System.Drawing.Color]::FromArgb(25,45,80)}))
 $lines = @('ORDONNANCE FICTIVE - TEST','Doliprane','Dafalgan','Ne pas utiliser comme prescription')
 $y=50
 foreach($line in $lines){$graphics.DrawString($line,$font,$ink,[single]60,[single]$y);$y+=110}
 $bitmap.Save((Join-Path $root ($definition.Name+'.png')),[System.Drawing.Imaging.ImageFormat]::Png)
 $ink.Dispose();$font.Dispose();$graphics.Dispose();$bitmap.Dispose()
}
