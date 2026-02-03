# -*- encoding: utf-8 -*-
"""
keri.kli.commands module

"""
import argparse
import sys

from hio.base import doing

from keri import help
from keri.app import signing
from keri.app.cli.common import existing
from keri.core import serdering
from keri.vdr import credentialing

logger = help.ogler.getLogger()

parser = argparse.ArgumentParser(description='Export multisig KEL, registries, and credentials in CESR format')
parser.set_defaults(handler=lambda args: export(args),
                    transferable=True)
parser.add_argument('--name', '-n', help='keystore name and file location of KERI keystore', required=True)
parser.add_argument('--alias', '-a', help='human readable alias for the multisig group AID', required=True)
parser.add_argument('--base', '-b', help='additional optional prefix to file location of KERI keystore',
                    required=False, default="")
parser.add_argument('--passcode', '-p', help='21 character encryption passcode for keystore (is not saved)',
                    dest="bran", default=None)  # passcode => bran


def export(args):
    ed = ExportDoer(name=args.name, alias=args.alias, base=args.base, bran=args.bran)
    return [ed]


class ExportDoer(doing.DoDoer):

    def __init__(self, name, alias, base, bran):
        self.hby = existing.setupHby(name=name, base=base, bran=bran)
        self.hab = self.hby.habByName(alias)
        self.rgy = credentialing.Regery(hby=self.hby, name=name, base=base)

        self.seen_kels = set()
        self.seen_tels = set()
        self.seen_creds = set()

        doers = [doing.doify(self.exportDo)]
        super(ExportDoer, self).__init__(doers=doers)

    def exportDo(self, tymth, tock=0.0):
        self.wind(tymth)
        self.tock = tock
        _ = (yield self.tock)

        self.outputKEL(pre=self.hab.pre)
        self.outputRegistries()
        self.outputIssuedCredentials()

    def outputKEL(self, pre):
        if pre in self.seen_kels:
            return
        self.seen_kels.add(pre)

        for msg in self.hby.db.clonePreIter(pre=pre):
            serder = serdering.SerderKERI(raw=msg)
            atc = msg[serder.size:]
            sys.stdout.write(serder.raw.decode("utf-8"))
            sys.stdout.write(atc.decode("utf-8"))
        sys.stdout.flush()

    def outputRegistries(self):
        for (name,), regord in self.rgy.reger.regs.getItemIter():
            if regord.prefix != self.hab.pre:
                continue
            self.outputTEL(regord.registryKey)

    def outputIssuedCredentials(self):
        saids = self.rgy.reger.issus.get(keys=self.hab.pre)
        for saider in saids:
            self.outputCred(saider.qb64)

    def outputCred(self, said):
        if said in self.seen_creds:
            return
        self.seen_creds.add(said)

        creder, *_ = self.rgy.reger.cloneCred(said=said)

        # export issuer KEL
        self.outputKEL(creder.issuer)

        # export TELs for registry + credential
        if creder.regi is not None:
            self.outputTEL(creder.regi)
            self.outputTEL(creder.said)

        # export chained credentials
        chains = creder.edge if creder.edge is not None else {}
        saids = []
        for key, source in chains.items():
            if key == 'd':
                continue
            if not isinstance(source, dict):
                continue
            saids.append(source['n'])
        for chain_said in saids:
            self.outputCred(chain_said)

        (prefixer, seqner, saider) = self.rgy.reger.cancs.get(keys=(creder.said,))
        sys.stdout.write(signing.serialize(creder, prefixer, seqner, saider).decode("utf-8"))
        sys.stdout.flush()

    def outputTEL(self, regk):
        if regk in self.seen_tels:
            return
        self.seen_tels.add(regk)

        for msg in self.rgy.reger.clonePreIter(pre=regk):
            serder = serdering.SerderKERI(raw=msg)
            atc = msg[serder.size:]
            sys.stdout.write(serder.raw.decode("utf-8"))
            sys.stdout.write(atc.decode("utf-8"))
        sys.stdout.flush()
