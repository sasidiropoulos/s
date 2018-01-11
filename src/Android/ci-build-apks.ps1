﻿$rootPath = $env:APPVEYOR_BUILD_FOLDER;

$androidPath = $($rootPath + "\src\Android\Android.csproj");
$appPath = $($rootPath + "\src\App\App.csproj");

echo "##### Increment Version"

$androidManifest = $($rootPath + "\src\Android\Properties\AndroidManifest.xml");

$xml=New-Object XML;
$xml.Load($androidManifest);

$node=$xml.SelectNodes("/manifest");
$node.SetAttribute("android:versionCode", $env:APPVEYOR_BUILD_NUMBER);

$xml.Save($androidManifest);

echo "##### Decrypt Keystore"

$encKeystorePath = $($rootPath + "\src\Android\8bit.keystore.enc");
..\..\secure-file\tools\secure-file -decrypt $($encKeystorePath) -secret $($env:keystore_password)

echo "##### Sign Release Configuration"

msbuild "Android.csproj" "/t:SignAndroidPackage" "/p:Configuration=Release" "/p:AndroidKeyStore=true" "/p:AndroidSigningKeyAlias=bitwarden" "/p:AndroidSigningKeyPass=$($env:keystore_password)" "/p:AndroidSigningKeyStore=8bit.keystore" "/p:AndroidSigningStorePass=$($env:keystore_password)"

echo "##### Copy Release apk to project root"

$signedApkPath = $($rootPath + "\src\Android\bin\Release\com.x8bit.bitwarden-Signed.apk");
$signedApkDestPath = $($rootPath + "\com.x8bit.bitwarden-" + $env:APPVEYOR_BUILD_NUMBER + ".apk");

Copy-Item $signedApkPath $signedApkDestPath

echo "##### Clean Android and App"

msbuild "$($androidPath)" "/t:Clean" "/p:Configuration=FDroid"
msbuild "$($appPath)" "/t:Clean" "/p:Configuration=FDroid"

echo "##### Backup project files"

Copy-Item $androidPath $($androidPath + ".original");
Copy-Item $appPath $($appPath + ".original");

echo "##### Uninstall from Android.csproj"

$xml=New-Object XML;
$xml.Load($androidPath);

$ns=New-Object System.Xml.XmlNamespaceManager($xml.NameTable);
$ns.AddNamespace("ns", $xml.DocumentElement.NamespaceURI);

$firebaseNode=$xml.SelectSingleNode("/ns:Project/ns:ItemGroup/ns:PackageReference[@Include='Xamarin.Firebase.Messaging']", $ns);
$firebaseNode.ParentNode.RemoveChild($firebaseNode);

$playServiceNode=$xml.SelectSingleNode("/ns:Project/ns:ItemGroup/ns:PackageReference[@Include='Xamarin.GooglePlayServices.Analytics']", $ns);
$playServiceNode.ParentNode.RemoveChild($playServiceNode);

$xml.Save($androidPath);

echo "##### Uninstall from App.csproj"

$xml=New-Object XML;
$xml.Load($appPath);

$hockeyNode=$xml.SelectSingleNode("/Project/ItemGroup/PackageReference[@Include='HockeySDK.Xamarin']");
$hockeyNode.ParentNode.RemoveChild($hockeyNode);

$xml.Save($appPath);

echo "##### Restore NuGet"

..\..\nuget.exe restore

echo "##### Build and Sign FDroid Configuration"

msbuild "Android.csproj" "/logger:C:\Program Files\AppVeyor\BuildAgent\Appveyor.MSBuildLogger.dll" "/p:Configuration=FDroid"
msbuild "Android.csproj" "/t:SignAndroidPackage" "/p:Configuration=FDroid" "/p:AndroidKeyStore=true" "/p:AndroidSigningKeyAlias=bitwarden" "/p:AndroidSigningKeyPass=$($env:keystore_password)" "/p:AndroidSigningKeyStore=8bit.keystore" "/p:AndroidSigningStorePass=$($env:keystore_password)"

echo "##### Copy FDroid apk to project root"

$signedApkPath = $($rootPath + "\src\Android\bin\FDroid\com.x8bit.bitwarden-Signed.apk");
$signedApkDestPath = $($rootPath + "\com.x8bit.bitwarden-fdroid-" + $env:APPVEYOR_BUILD_NUMBER + ".apk");

Copy-Item $signedApkPath $signedApkDestPath

echo "##### Done"
