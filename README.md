# About

This creates an iso file with the latest Windows available from the [Unified Update Platform (UUP)](https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview).

This shrink wraps the [UUP dump](https://git.uupdump.net/uup-dump) project into a single command.

# The whole was written for the use with Github Actions.
Just fork this repository and use Github Actions to build your own version.

Once the GitHub actions are complete, you'll receive a finished ISO image in two flavors.

1. Release with the .iso file split into several parts (as GitHub doesn't allow files larger than 2GB to be included in a release).
Additionally, for each release, packages are created for various systems and architectures, containing a ready-made script that downloads all parts of the split ISO and returns the finished ISO file.
2. Artifacts - a single zip file, but logging in to the website is required to download.

# You can also executed directly on a Windows x64 or arm64 host (min. 21H2).

## This supports the following: 
Windows Builds:
* `windows-10`: Windows 10 19045 (aka 22H2)
* `windows-11old`: Windows 11 22631 (aka 23H2)
* `windows-11`: Windows 11 26100 (aka 24H2)
* `windows-11beta`: Windows 11 26120 (aka 24H2 BETA)
* `windows-11new`: Windows 11 26200 (aka 25H2)
* `windows-11dev`: Windows 11 26220 (aka 25H2 BETA)
* `windows-1126h1`: Windows 11 28000 (aka 26H1) <details><summary>Details</summary>for new 2026 devices with select new silicon (e.g., Snapdragon X2) to enable new hardware innovations - not for existing PCs or general enterprise deployments.</details>

* `windows-1126h2`: Windows 11 26300 (aka 26H2 BETA)
* `windows-dev`: Windows 11 26300 (aka DEV)
* `windows-canary`: Windows 11 Insider Preview (aka CANARY)


Architecture:
* `x64`
* `arm64`


Edition:
* `home`
* `pro`
* `multi`: Home + Pro


Language:
* `ar-sa`: Arabic (Saudi Arabia)
* `bg-bg`: Bulgarian (Bulgaria)
* `cs-cz`: Czech (Czech Republic)
* `da-dk`: Danish (Denmark)
* `de-de`: German (Germany)
* `el-gr`: Greek (Greece)
* `en-gb`: English (United Kingdom)
* `en-us`: English (United States)
* `es-es`: Spanish (Spain)
* `es-mx`: Spanish (Mexico)
* `et-ee`: Estonian (Estonia)
* `fi-fi`: Finnish (Finland)
* `fr-ca`: French (Canada)
* `fr-fr`: French (France)
* `he-il`: Hebrew (Israel)
* `hr-hr`: Croatian (Croatia)
* `hu-hu`: Hungarian (Hungary)
* `it-it`: Italian (Italy)
* `ja-jp`: Japanese (Japan)
* `ko-kr`: Korean (Korea)
* `lt-lt`: Lithuanian (Lithuania)
* `lv-lv`: Latvian (Latvia)
* `nb-no`: Norwegian Bokmål (Norway)
* `nl-nl`: Dutch (Netherlands)
* `pl-pl`: Polish (Poland)
* `pt-br`: Portuguese (Brazil)
* `pt-pt`: Portuguese (Portugal)
* `ro-ro`: Romanian (Romania)
* `ru-ru`: Russian (Russia)
* `sk-sk`: Slovak (Slovakia)
* `sl-si`: Slovenian (Slovenia)
* `sr-latn-rs`: Serbian (Latin, Serbia)
* `sv-se`: Swedish (Sweden)
* `th-th`: Thai (Thailand)
* `tr-tr`: Turkish (Turkey)
* `uk-ua`: Ukrainian (Ukraine)
* `zh-cn`: Chinese (Simplified, China)
* `zh-tw`: Chinese (Traditional, Taiwan)


Additional options:
* `esd`: Use ESD compression
* `drivers`: Add drivers from Drivers folder
* `netfx3`: Add .NET Framework 3.5
* `revision`: System Revision Number


## Usage

Get the latest Windows 11 25H2 iso:

```bash
powershell uup-dump-get-windows-iso.ps1 windows-11new c:/output -architecture x64 -edition pro -lang en-us -esd -drivers -netfx3
```

When everything works correctly, you'll have the iso in the `output` directory at, e.g., `c:/output/26200.7899.250826-1428.25H2_GE_RELEASE_SVC_PROD3_CLIENTPRO_OEMRET_X64FRE_PL-PL.ISO`.

You can also download the system revision of your choice. For example, if you want to build 25H2 26200.7705 iso:

```bash
powershell uup-dump-get-windows-iso.ps1 windows-11new c:/output -architecture x64 -edition pro -lang en-us -esd -drivers -netfx3 -revision 7705
```


## Tags structure

```text
  .------------------------------- OS Build
  |    .-------------------------- System Revision
  |    |    .--------------------- Release Channel/Version
  |    |    |    .---------------- System Edition
  |    |    |    |   .------------ CPU architecture
  |    |    |    |   |  .--------- Language
  |    |    |    |   |  |  .------ Image is compressed by ESD (optional)
  |    |    |    |   |  |  | .---- Include additional drivers (optional)
  |    |    |    |   |  |  | | .-- Include .NET Framework 3.5 (optional)
__|__ _|__ _|__ _|_ _|_ |_ | | |
26200.7899.25H2.PRO.X64.PL.E.D.N
```

## Related Tools

* [Rufus](https://github.com/pbatard/rufus)
* [Fido](https://github.com/pbatard/Fido)
* [windows-evaluation-isos-scraper](https://github.com/rgl/windows-evaluation-isos-scraper)

## Reference

* [UUP dump home](https://uupdump.net)
* [UUP dump source code](https://git.uupdump.net/uup-dump)
* [Unified Update Platform (UUP)](https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview)
