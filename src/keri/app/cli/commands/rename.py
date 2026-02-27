# -*- encoding: utf-8 -*-
"""
KERI
keri.kli.commands module

"""
import argparse

from keri import help
from hio.base import doing

from keri.app.cli.common import existing
from keri.kering import ConfigurationError

logger = help.ogler.getLogger()

parser = argparse.ArgumentParser(description='Change the alias for a local identifier')
parser.set_defaults(handler=lambda args: handler(args),
                    transferable=True)
parser.add_argument('--name', '-n', help='keystore name and file location of KERI keystore', required=True)
parser.add_argument('--base', '-b', help='additional optional prefix to file location of KERI keystore',
                    required=False, default="")
parser.add_argument('--alias', '-a', help='human readable alias for the identifier prefix', required=True)
parser.add_argument('new', help='new human readable alias for the identifier')
parser.add_argument('--passcode', '-p', help='21 character encryption passcode for keystore (is not saved)',
                    dest="bran", default=None)  # passcode => bran


def handler(args):
    kwa = dict(args=args)
    return [doing.doify(rename, **kwa)]


def rename(tymth, tock=0.0, **opts):
    """ Command line status handler

    """
    _ = (yield tock)
    args = opts["args"]
    name = args.name
    alias = args.alias
    base = args.base
    bran = args.bran
    newAlias = args.new

    with existing.existingHby(name=name, base=base, bran=bran) as hby:
        hab = hby.habByPre(pre=alias) or hby.habByName(name=alias)

        if hab is None:
            print(f"No AID with name {alias} found")
            return -1

        if hby.habByName(newAlias) is not None:
            print(f"{newAlias} is already in use")
            return -1

        if (pre := hab.db.names.get(keys=("", alias))) is not None:
            habord = hab.db.habs.get(keys=pre)
            habord.name = newAlias
            hab.db.habs.pin(keys=habord.hid, val=habord)
            hab.db.names.pin(keys=("", newAlias), val=pre)
            hab.db.names.rem(keys=("", alias))

            print(f"Hab {alias} renamed to {newAlias}")
        else:
            print(f"No AID with name {alias} found")
            return -1
