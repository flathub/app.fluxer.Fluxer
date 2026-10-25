# Fluxer Flatpak

This repo hosts the Flatpak manifest for [Fluxer, available at Flathub](https://flathub.org/en/apps/app.fluxer.Fluxer).

<a href='https://flathub.org/apps/app.fluxer.Fluxer'>
  <img width='240' alt='Get it on Flathub' src='https://flathub.org/api/badge?locale=en'/>
</a>


```bash
flatpak install flathub app.fluxer.Fluxer
flatpak run flathub app.fluxer.Fluxer
```

### Persistent flags

To make Fluxer's launch flags persistent, add them to `~/.var/app/app.fluxer.Fluxer/config/fluxer-flags.conf` (one option per line):

```
# This is just an example
--ozone-platform-hint=auto
# This line will be ignored
--enable-features=WaylandWindowDecorations
```

### File Access

Default Flatpak permissions for this package limit Fluxer's ability to access your file system. Fluxer uses xdg-desktop-portal's file chooser portal to provide an interface to upload files. If your environment doesn't support this, you can manually give Fluxer access to as many directories as you want with [Flatseal](https://flathub.org/en/apps/com.github.tchx84.Flatseal) or `flatpak override`.

### Reporting bugs

Before reporting a bug, please try to replicate the issue on a non-sandboxed official package first. If the problem only occurs on the Flatpak, feel free to open an issue on this repository. Otherwise, report it at [`feedback.fluxer.com`](https://feedback.fluxer.com).