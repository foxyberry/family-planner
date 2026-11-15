#!/usr/bin/env python3
"""Works out board formulas on every iPad the app checks, so a floor is tried on all sizes at once.

Usage: python3 scale.py [--top N] "max(176*s,142)" "472*s - 2*max(24*s,16)" ...
An expression may use numbers, + - * / ( ), the names s, W, H, top and the calls max, min, fluid.
fluid(ref, lo) = max(lo, ref * s). s = min(W/1376, (H - top)/1008) with a 0.70 lower bound
(spec "Sizing formulas"). --top N replaces every iPad's safe.top with a value read on a device.
"""
import ast
import operator
import sys

IPADS = [  # name, W, H, safe.top (landscape, full screen)
    ("13in", 1376, 1032, 24),
    ("12.9in", 1366, 1024, 32),
    ("Pro 11in", 1210, 834, 24),
    ("11in", 1180, 820, 24),
    ("mini", 1133, 744, 24),
]
OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul, ast.Div: operator.truediv}


def scale(W, H, top):
    return max(0.70, min(W / 1376, (H - top) / 1008))


def evaluate(node, env):
    if isinstance(node, ast.Expression):
        return evaluate(node.body, env)
    if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
        return node.value
    if isinstance(node, ast.Name) and node.id in env:
        return env[node.id]
    if isinstance(node, ast.BinOp) and type(node.op) in OPS:
        return OPS[type(node.op)](evaluate(node.left, env), evaluate(node.right, env))
    if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
        return -evaluate(node.operand, env)
    if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and not node.keywords:
        args = [evaluate(a, env) for a in node.args]
        if node.func.id == "max":
            return max(args)
        if node.func.id == "min":
            return min(args)
        if node.func.id == "fluid" and len(args) == 2:
            return max(args[1], args[0] * env["s"])
    raise ValueError(f"not allowed: {ast.unparse(node)}")


def main(argv):
    top_override = None
    if len(argv) >= 2 and argv[0] == "--top":
        top_override, argv = float(argv[1]), argv[2:]
    if not argv:
        print(__doc__)
        return 2
    ipads = [(n, W, H, top_override if top_override is not None else t) for n, W, H, t in IPADS]
    print(f"{'':34}" + "".join(f"{n:>10}" for n, *_ in ipads))
    print(f"{'s':34}" + "".join(f"{scale(W, H, t):>10.3f}" for _, W, H, t in ipads))
    status = 0
    for expr in argv:
        try:
            tree = ast.parse(expr, mode="eval")
            row = [evaluate(tree, {"s": scale(W, H, t), "W": W, "H": H, "top": t}) for _, W, H, t in ipads]
            print(f"{expr[:34]:34}" + "".join(f"{v:>10.1f}" for v in row))
        except (SyntaxError, ValueError, ZeroDivisionError) as err:
            print(f"{expr[:34]:34}  error: {err}")
            status = 1
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
