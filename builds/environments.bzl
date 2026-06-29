"""Compatibility environment values for KISS-only project declarations."""

def environment(name):
    return struct(name = name)

LOCAL = environment("local")
RBE = environment("rbe")
ACTIOND = environment("actiond")
MINIMG = environment("minimg")
CIIMG = environment("ciimg")
