# Fix Cart_Page.dart by removing orphaned code
$filePath = "lib\screens\SuperMarket\Cart_Page.dart"
$content = Get-Content $filePath -Raw
$lines = $content -split "`n"

# Keep lines 0-919 (up to and including the _safeToInt method closing brace)
# Skip the orphaned code
# Find the next valid _buildCartContent method

$output = @()
$inOrphanedSection = $false

for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -le 919) {
        # Keep everything up to line 919
        $output += $lines[$i]
    }
    elseif ($lines[$i] -match '^\s*Widget _buildCartContent\(\)') {
        # Found the valid _buildCartContent method
        $inOrphanedSection = $false
        $output += ""  # Add blank line
        $output += $lines[$i]
    }
    elseif (-not $inOrphanedSection -and $i -gt 919) {
        # We're in the orphaned section
        $inOrphanedSection = $true
    }
    elseif (-not $inOrphanedSection) {
        # Keep valid code after orphaned section
        $output += $lines[$i]
    }
}

$output -join "`n" | Set-Content $filePath -NoNewline
Write-Host "Cart_Page.dart fixed successfully!"
