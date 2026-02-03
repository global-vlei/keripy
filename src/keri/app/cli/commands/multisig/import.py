# -*- encoding: utf-8 -*-
"""
keri.kli.commands module

"""
import argparse
import sys

from hio.base import doing

from keri import help, kering
from keri.app import habbing
from keri.app.cli.common import existing
from keri.core import parsing, serdering
from keri.db import dbing
from keri.vdr import credentialing, verifying, viring

logger = help.ogler.getLogger()

parser = argparse.ArgumentParser(description='Import multisig KEL, registries, and credentials from CESR stream')
parser.set_defaults(handler=lambda args: import_multisig(args),
                    transferable=True)
parser.add_argument('--name', '-n', help='keystore name and file location of KERI keystore', required=True)
parser.add_argument('--alias', '-a', help='human readable alias for the multisig group AID', required=True)
parser.add_argument('--base', '-b', help='additional optional prefix to file location of KERI keystore',
                    required=False, default="")
parser.add_argument('--passcode', '-p', help='21 character encryption passcode for keystore (is not saved)',
                    dest="bran", default=None)  # passcode => bran
parser.add_argument('--file', help='optional path to CESR stream file (default stdin)', required=False, default=None)
parser.add_argument("--auto", help="Automatically accept default registry names during import",
                    action="store_true")


def import_multisig(args):
    idr = ImportDoer(name=args.name, alias=args.alias, base=args.base, bran=args.bran,
                     path=args.file, auto=args.auto)
    return [idr]


def resolveInput(path):
    if path:
        with open(path, "rb") as f:
            return f.read()
    if sys.stdin.isatty():
        return b""
    return sys.stdin.buffer.read()


class ImportDoer(doing.DoDoer):

    def __init__(self, name, alias, base, bran, path, auto=False):
        self.hby = existing.setupHby(name=name, base=base, bran=bran)
        self.hab = self.hby.habByName(alias)
        self.rgy = credentialing.Regery(hby=self.hby, name=name, base=base)
        self.vry = verifying.Verifier(hby=self.hby, reger=self.rgy.reger)

        self.psr = parsing.Parser(kvy=self.hby.kvy, tvy=self.rgy.tvy, vry=self.vry)
        self.hbyDoer = habbing.HaberyDoer(habery=self.hby)
        self.path = path
        self.auto = auto

        doers = [self.hbyDoer, doing.doify(self.importDo)]
        self.toRemove = list(doers)
        super(ImportDoer, self).__init__(doers=doers)

    def importDo(self, tymth, tock=0.0):
        self.wind(tymth)
        self.tock = tock
        _ = (yield self.tock)

        ims = resolveInput(self.path)
        if not ims:
            raise kering.ConfigurationError("No CESR stream input provided")

        try:
            self.psr.parse(ims=ims)
        except kering.MissingAnchorError as ex:
            raise kering.ConfigurationError(f"Missing KEL anchor for registry/TEL import: {ex}")
        except kering.MissingRegistryError as ex:
            raise kering.ConfigurationError(f"Missing registry during credential import: {ex}")

        self._nameRegistries()
        self.remove(self.toRemove)
        return True

    def _nameRegistries(self):
        regks = self._discoverRegistriesFromTEL()
        for regk in regks:
            if regk in self.rgy.regs or regk in self.rgy.reger.registries:
                continue
            if self._isRegistryNamed(regk):
                continue

            registryName = self._promptRegistryName(regk)
            if self._isRegistryNamed(regk):
                continue

            try:
                reg = credentialing.Registry(hab=self.hab, name=registryName, reger=self.rgy.reger,
                                             tvy=self.rgy.tvy, psr=self.rgy.psr, regk=regk,
                                             cues=self.rgy.cues)
                reg.inited = True
                self.rgy.regs[regk] = reg
                self.rgy.reger.registries.add(regk)
                self.rgy.reger.regs.put(keys=registryName,
                                        val=viring.RegistryRecord(registryKey=regk, prefix=self.hab.pre))
                print(f"Registry {registryName} ({regk}) named locally.")
            except kering.KeriError as ex:
                print(f"Failed to name registry for {regk}: {ex}")

    def _discoverRegistriesFromTEL(self):
        regks = []
        seen = set()

        for pre, sn, dig in self.rgy.reger.getOnItemIter(db=self.rgy.reger.tels, key=b"", on=0):
            if sn != 0:
                continue
            key = dbing.dgKey(pre=pre, dig=dig)
            raw_tvt = self.rgy.reger.getTvt(key)
            if raw_tvt is None:
                continue
            try:
                vserder = serdering.SerderKERI(raw=bytes(raw_tvt))
            except Exception:
                continue
            if vserder.ilk != kering.Ilks.vcp:
                continue
            if vserder.ked.get("ii") != self.hab.pre:
                continue
            regk = vserder.pre
            if regk in seen:
                continue
            seen.add(regk)
            regks.append(regk)

        return regks

    def _isRegistryNamed(self, regk):
        for _, regord in self.rgy.reger.regs.getItemIter():
            if regord.registryKey == regk:
                return True
        return False

    def _promptRegistryName(self, regk):
        default_name = self.hab.name
        if (rec := self.rgy.reger.regs.get(default_name)) is not None and rec.registryKey != regk:
            default_name = f"reg-{regk[:8]}"
        if self.auto:
            print(f"Name for Registry [{default_name}]: {default_name}")
            return default_name
        while True:
            entered = input(f"Name for Registry [{default_name}]: ").strip()
            registryName = entered if entered else default_name
            if (rec := self.rgy.reger.regs.get(registryName)) is None:
                return registryName
            if rec.registryKey == regk:
                return registryName
            print(f"Registry name '{registryName}' already in use, please choose another.")
