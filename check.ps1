Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Install-Module -Name powershell-yaml -AcceptLicense
Import-Module powershell-yaml
gh auth setup-git
git config --global user.email "kieseljake+rust-winget-bot@live.com"
git config --global user.name "Rust-Winget-Bot"
gh repo clone "Rust-Winget-Bot/winget-pkgs"
cd winget-pkgs
git pull upstream master
git push
$lastFewVersions = git ls-remote --sort=-v:refname --tags https://github.com/rust-lang/rust.git | Foreach-Object {(($_ -split '\t')[1]).Substring(10)} | Where-Object {!$_.Contains('release') -and !$_.Contains('^')} | Select -First 3;
$myPrs = gh pr list --author "Rust-Winget-Bot" --repo "microsoft/winget-pkgs" --state=all | Foreach-Object {((($_ -split '\t')[2]) -split ':')[1]};
foreach ($toolchain in @("MSVC", "GNU")) {
    $toolchainLower = $toolchain.ToLower();
    $publishedVersions = Get-ChildItem .\manifests\r\Rustlang\Rust\$toolchain | Foreach-Object {$_.Name} | Where-Object {!$_.Contains('.validation')} | Select -Last 5
    foreach ($version in $lastFewVersions) {
        if ($publishedVersions.Contains($version)) {
            continue;
        } else {
            if ($myPrs -and $myPrs.Contains("rust-$version-$toolchainLower")) {
                continue;
            }
            Write-Output "Creating branch for $version $toolchain"
            git checkout master;
            git checkout -b rust-$version-$toolchainLower;
            New-Item "manifests/r/Rustlang/Rust/$toolchain/$version/" -ItemType Directory -ea 0
            $yamlPath = "manifests/r/Rustlang/Rust/$toolchain/$version/Rustlang.Rust.$toolchain.installer.yaml";
            $yamlObject = New-Object –TypeName PSObject;
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageIdentifier -Value "Rustlang.Rust.$toolchain"
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageVersion -Value $version
            $yamlObject | Add-Member -MemberType NoteProperty -Name MinimumOSVersion -Value "10.0.0.0"
            $yamlObject | Add-Member -MemberType NoteProperty -Name InstallerType -Value wix
            $yamlObject | Add-Member -MemberType NoteProperty -Name UpgradeBehavior -Value uninstallPrevious
            $yamlObject | Add-Member -MemberType NoteProperty -Name ManifestType -Value installer
            $yamlObject | Add-Member -MemberType NoteProperty -Name ManifestVersion -Value "1.2.0"
             if ($toolchain -eq "MSVC") {
                $installers = @("https://static.rust-lang.org/dist/rust-$version-aarch64-pc-windows-msvc.msi", "https://static.rust-lang.org/dist/rust-$version-i686-pc-windows-msvc.msi", "https://static.rust-lang.org/dist/rust-$version-x86_64-pc-windows-msvc.msi")
            } else {
                $installers = @("https://static.rust-lang.org/dist/rust-$version-i686-pc-windows-gnu.msi", "https://static.rust-lang.org/dist/rust-$version-x86_64-pc-windows-gnu.msi")
            }
            $yamlObject | Add-Member -MemberType NoteProperty -Name Installers -Value @()
            foreach ($installer in $installers) {
                $path = $installer.Substring($installer.LastIndexOf('/') + 1);
                Write-Output "Now downloading $path from $installer"
                curl -LO $installer
                $sha256 = (Get-FileHash $path -Algorithm SHA256).Hash;
                Remove-Item $path;
                curl -LO $installer
                $sha256_2 = (Get-FileHash $path -Algorithm SHA256).Hash;
                Remove-Item $path;
                if (-not($sha256 -eq $sha256_2)) {
                    throw "Sha256 returned two different results, shutting down to lack of confidence in sha value"
                }
                $productCode = "{$((New-Guid).Guid.ToUpper())}";
                $arch = if ($installer.Contains("i686")) {
                    "x86"
                } elseif ($installer.Contains("x86_64")) {
                    "x64"
                } elseif ($installer.Contains("aarch64")) {
                    "arm64"
                }
                $bits = if ($arch -eq "x86") {
                    "32-bit"
                } elseif ($arch -eq "x64") {
                    "64-bit"
                } elseif ($arch -eq "arm64") {
                    "arm64"
                };
                $installerEntry = New-Object –TypeName PSObject;
                $appsAndFeaturesEntry = New-Object –TypeName PSObject;
                $appsAndFeaturesEntry | Add-Member -MemberType NoteProperty -Name ProductCode -Value $productCode
                $appsAndFeaturesEntry | Add-Member -MemberType NoteProperty -Name DisplayName -Value "Rust $version ($toolchain $bits)";
                $appsAndFeaturesEntry | Add-Member -MemberType NoteProperty -Name DisplayVersion -Value "$version.0"
                $installerEntry | Add-Member -MemberType NoteProperty -Name Architecture -Value $arch
                $installerEntry | Add-Member -MemberType NoteProperty -Name InstallerUrl -Value $installer
                $installerEntry | Add-Member -MemberType NoteProperty -Name InstallerSha256 -Value $sha256
                $installerEntry | Add-Member -MemberType NoteProperty -Name AppsAndFeaturesEntries -Value @($appsAndFeaturesEntry);
                $yamlObject.Installers += $installerEntry
            }
            $newYamlData = ConvertTo-YAML $yamlObject;
            Set-Content -Path $yamlPath -Value $newYamlData;
            $yamlPath = "manifests/r/Rustlang/Rust/$toolchain/$version/Rustlang.Rust.$toolchain.locale.en-US.yaml";
            $yamlObject = New-Object –TypeName PSObject;
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageIdentifier -Value "Rustlang.Rust.$toolchain"
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageVersion -Value $version
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageLocale -Value "en-US"
            $yamlObject | Add-Member -MemberType NoteProperty -Name Publisher -Value "The Rust Project Developers"
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageName -Value "Rust ($toolchain)"
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageUrl -Value "https://www.rust-lang.org/"
            $yamlObject | Add-Member -MemberType NoteProperty -Name License -Value "Apache 2.0 and MIT"
            $yamlObject | Add-Member -MemberType NoteProperty -Name LicenseUrl -Value "https://raw.githubusercontent.com/rust-lang/rust/master/COPYRIGHT"
            $yamlObject | Add-Member -MemberType NoteProperty -Name ShortDescription -Value "this is the rust-lang built with $toolchainLower toolchain"
            $yamlObject | Add-Member -MemberType NoteProperty -Name Moniker -Value "rust-$toolchainLower"
            $yamlObject | Add-Member -MemberType NoteProperty -Name ManifestType -Value "defaultLocale"
            $yamlObject | Add-Member -MemberType NoteProperty -Name ManifestVersion -Value "1.2.0"
            $yamlObject | Add-Member -MemberType NoteProperty -Name Tags -Value @($toolchainLower, "rust", "windows")
            $newYamlData = ConvertTo-YAML $yamlObject;
            Set-Content -Path $yamlPath -Value $newYamlData;
            $yamlPath = "manifests/r/Rustlang/Rust/$toolchain/$version/Rustlang.Rust.$toolchain.yaml";
            $yamlObject = New-Object –TypeName PSObject;
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageIdentifier -Value "Rustlang.Rust.$toolchain"
            $yamlObject | Add-Member -MemberType NoteProperty -Name PackageVersion -Value $version
            $yamlObject | Add-Member -MemberType NoteProperty -Name DefaultLocale -Value "en-US"
            $yamlObject | Add-Member -MemberType NoteProperty -Name ManifestType -Value "version"
            $yamlObject | Add-Member -MemberType NoteProperty -Name ManifestVersion -Value "1.2.0"
            $newYamlData = ConvertTo-YAML $yamlObject;
            Set-Content -Path $yamlPath -Value $newYamlData;
            git add --all .
            git commit -m"add Rustlang.Rust.$toolchain version $version"
            git push -u origin rust-$version-$toolchainLower;
            # Uncomment this once we've seen it work a few times and are happy with it.
            # gh pr create --title "add Rustlang.Rust.$toolchain version $version" --body "I'm a bot and this PR was opened automatically. If there's something wrong, please file an issue at https://github.com/Rust-Winget-Bot/bot-issues/issues"
        }
    }
}
