self: super: {
  lib = (super.lib or { }) // {
    qois = import ../lib { lib = self.lib; };
  };
}
