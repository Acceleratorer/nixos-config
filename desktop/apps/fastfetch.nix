{ palette }:

{
  logo = {
    type = "builtin";
    source = "NixOS";
  };

  display = {
    brightColor = false;
    separator = "  ";

    color = {
      keys = palette.muted;
      title = palette.accent;
      output = palette.foreground;
      separator = palette.border;
    };

    key.width = 12;
  };

  modules = [
    {
      type = "title";
      format = "CryoForge // {user-name}@{host-name}";
    }
    {
      type = "os";
      key = "OS";
    }
    {
      type = "host";
      key = "Host";
    }
    {
      type = "kernel";
      key = "Kernel";
    }
    {
      type = "uptime";
      key = "Uptime";
    }
    {
      type = "packages";
      key = "Packages";
    }
    {
      type = "break";
    }
    {
      type = "shell";
      key = "Shell";
    }
    {
      type = "terminal";
      key = "Terminal";
    }
    {
      type = "wm";
      key = "Desktop";
    }
    {
      type = "break";
    }
    {
      type = "cpu";
      key = "CPU";
    }
    {
      type = "gpu";
      key = "GPU";
    }
    {
      type = "memory";
      key = "Memory";
    }
    {
      type = "disk";
      key = "Storage";
      folders = "/";
    }
  ];
}
