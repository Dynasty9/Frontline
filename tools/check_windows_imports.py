"""Reject Windows native artifacts that need an unbundled C/C++ runtime."""
from pathlib import Path
import argparse
import struct


def imports(path):
    data = path.read_bytes()
    pe = struct.unpack_from("<I", data, 60)[0]
    if data[pe:pe + 4] != b"PE\0\0" or struct.unpack_from("<H", data, pe + 24)[0] != 0x20B:
        raise ValueError(f"Expected a 64-bit PE artifact: {path}")
    count = struct.unpack_from("<H", data, pe + 6)[0]
    optional_size = struct.unpack_from("<H", data, pe + 20)[0]
    sections = [struct.unpack_from("<IIII", data, pe + 24 + optional_size + i * 40 + 8)
                for i in range(count)]

    def offset(rva):
        return next(raw + rva - address for virtual, address, size, raw in sections
                    if address <= rva < address + max(virtual, size))

    table = struct.unpack_from("<I", data, pe + 24 + 120)[0]
    if not table:
        return []
    cursor = offset(table)
    names = []
    while any(row := struct.unpack_from("<IIIII", data, cursor)):
        name = offset(row[3])
        names.append(data[name:data.index(b"\0", name)].decode("ascii"))
        cursor += 20
    return names


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("artifacts", type=Path, nargs="+")
    for artifact in parser.parse_args().artifacts:
        names = imports(artifact)
        runtime = [name for name in names if name.lower().startswith(
            ("vcruntime", "msvcp", "msvcr", "ucrtbase", "api-ms-win-crt"))]
        if runtime:
            raise SystemExit(f"{artifact.name} requires external runtime DLLs: {', '.join(runtime)}")
        print(f"{artifact.name}: no external C/C++ runtime imports ({', '.join(names)})")
