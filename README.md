# About

This creates an iso file with the latest Windows Server available from the [Unified Update Platform (UUP)](https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview).

This shrink wraps the [UUP dump](https://git.uupdump.net/uup-dump) project into a single command.

# The whole was written for the use with Github Actions.
Just fork this repository and use Github Actions to build your own version.

Once the GitHub actions are complete, you'll receive a finished ISO image in two flavors.

1. Release with the .iso file split into several parts (as GitHub doesn't allow files larger than 2GB to be included in a release).
Additionally, for each release, packages are created for various systems and architectures, containing a ready-made script that downloads all parts of the split ISO and returns the finished ISO file.
2. Artifacts - a single zip file, but logging in to the website is required to download.

# You can also executed directly on a Windows x64 host (min. 21H2).

## This supports the following:
Windows Server Builds:
* `server-2022`: Windows Server 2022 20348 (aka 21H2)
* `server-23h2`: Windows Server, version 23H2 25398
* `server-2025`: Windows Server 2025 26100


Architecture:
* `x64`


Edition:
* `standard`: Windows Server Standard
* `standard-core`: Windows Server Standard, Core
* `datacenter`: Windows Server Datacenter
* `datacenter-core`: Windows Server Datacenter, Core
* `datacenter-azure`: Windows Server Datacenter Azure
* `datacenter-azure-core`: Windows Server Datacenter Azure, Core
* `azure-stack-hci`: Azure Stack HCI

Edition availability depends on the selected server target. Windows Server 2022 supports Standard/Datacenter and Core variants, Windows Server 2025 supports Standard/Datacenter and Azure variants, and Windows Server, version 23H2 supports Datacenter Core and Azure Stack HCI.


Language:
* `cs-cz`: Czech (Czech Republic)
* `de-de`: German (Germany)
* `en-us`: English (United States)
* `es-es`: Spanish (Spain)
* `fr-fr`: French (France)
* `hu-hu`: Hungarian (Hungary)
* `it-it`: Italian (Italy)
* `ja-jp`: Japanese (Japan)
* `ko-kr`: Korean (Korea)
* `nl-nl`: Dutch (Netherlands)
* `pl-pl`: Polish (Poland)
* `pt-br`: Portuguese (Brazil)
* `pt-pt`: Portuguese (Portugal)
* `ru-ru`: Russian (Russia)
* `sv-se`: Swedish (Sweden)
* `tr-tr`: Turkish (Turkey)
* `zh-cn`: Chinese (Simplified, China)
* `zh-tw`: Chinese (Traditional, Taiwan)


Additional options:
* `esd`: Use ESD compression
* `drivers`: Add drivers from Drivers folder
* `netfx3`: Add .NET Framework 3.5
* `revision`: System Revision Number


## Usage

Get the latest Windows Server 2025 Datacenter Core iso:

```bash
powershell uup-dump-get-windows-iso.ps1 server-2025 c:/output -architecture x64 -edition datacenter-core -lang en-us -esd -drivers -netfx3
```

When everything works correctly, you'll have the iso in the `output` directory at, e.g., `c:/output/26100.32690.260401-1700.GE_RELEASE_SVC_PROD3_SERVERDATACENTERCORE_OEMRET_X64FRE_EN-US.ISO`.

You can also download the system revision of your choice. For example, if you want to build Windows Server 2025 26100.32690 iso:

```bash
powershell uup-dump-get-windows-iso.ps1 server-2025 c:/output -architecture x64 -edition datacenter-core -lang en-us -esd -drivers -netfx3 -revision 32690
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
26100.32690.2025.DATACENTERCORE.X64.EN.E.D.N
```

## Related Tools

* [Rufus](https://github.com/pbatard/rufus)
* [Fido](https://github.com/pbatard/Fido)
* [windows-evaluation-isos-scraper](https://github.com/rgl/windows-evaluation-isos-scraper)

## Reference

* [UUP dump home](https://uupdump.net)
* [UUP dump source code](https://git.uupdump.net/uup-dump)
* [Unified Update Platform (UUP)](https://docs.microsoft.com/en-us/windows/deployment/update/windows-update-overview)
