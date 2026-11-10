"""One-client localhost UDP impairment proxy for ENet animation regression runs."""
import argparse
import heapq
import json
import random
import select
import socket
import time


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--listen', type=int, default=7991)
    parser.add_argument('--server', type=int, default=7990)
    parser.add_argument('--delay-ms', type=float, default=75)
    parser.add_argument('--jitter-ms', type=float, default=20)
    parser.add_argument('--loss', type=float, default=0.02)
    parser.add_argument('--seconds', type=float, default=120)
    parser.add_argument('--seed', type=int, default=3)
    args = parser.parse_args()
    if not (0 <= args.loss < 1 and 0 <= args.jitter_ms <= args.delay_ms and args.seconds > 0):
        parser.error('Use loss in [0,1), nonnegative jitter <= delay, and positive duration')
    rng = random.Random(args.seed)
    pending = []
    sequence = 0
    client = None
    counts = {'received': 0, 'dropped': 0, 'forwarded': 0}
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as front, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as back:
        front.bind(('127.0.0.1', args.listen))
        back.bind(('127.0.0.1', 0))
        server = ('127.0.0.1', args.server)
        deadline = time.monotonic() + args.seconds
        print('PROXY READY', json.dumps(vars(args)), flush=True)
        while time.monotonic() < deadline:
            now = time.monotonic()
            timeout = min(0.02, max(0, pending[0][0] - now)) if pending else 0.02
            readable, _, _ = select.select([front, back], [], [], timeout)
            for source in readable:
                try:
                    data, sender = source.recvfrom(65535)
                except ConnectionResetError:
                    # Windows reports ICMP while the host is still starting.
                    continue
                if source is front:
                    if client is not None and sender != client:
                        continue
                    client = sender
                    destination, target = back, server
                else:
                    if sender != server or client is None:
                        continue
                    destination, target = front, client
                counts['received'] += 1
                if rng.random() < args.loss:
                    counts['dropped'] += 1
                    continue
                due = time.monotonic() + (args.delay_ms + rng.uniform(-args.jitter_ms, args.jitter_ms)) / 1000
                heapq.heappush(pending, (due, sequence, destination, target, data))
                sequence += 1
            now = time.monotonic()
            while pending and pending[0][0] <= now:
                _, _, destination, target, data = heapq.heappop(pending)
                destination.sendto(data, target)
                counts['forwarded'] += 1
        print('PROXY FINISHED', json.dumps(counts), flush=True)


if __name__ == '__main__':
    main()
