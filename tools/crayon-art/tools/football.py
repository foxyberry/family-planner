# Classic football face-on: a central black pentagon, five seams out to five black patches that the ball's edge cuts off,
# and the hexagon seams between neighbouring patches. Patches and seams are clipped to the ball by pulling outside points onto the rim.
import math, sys
cx, cy, R = 120, 116, 86
a, D, b = float(sys.argv[1]), float(sys.argv[2]), float(sys.argv[3])
rim = R - 1.5
def P(r, deg, ox=cx, oy=cy): t = math.radians(deg); return (ox + r * math.cos(t), oy + r * math.sin(t))
def clamp(p):
    dx, dy = p[0] - cx, p[1] - cy; d = math.hypot(dx, dy)
    return p if d <= rim else (cx + dx / d * rim, cy + dy / d * rim)
def dense(pts, closed=True, step=1.5):
    out = []; n = len(pts)
    for i in range(n if closed else n - 1):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % n]; k = max(1, int(math.hypot(x2 - x1, y2 - y1) / step))
        out += [(x1 + (x2 - x1) * j / k, y1 + (y2 - y1) * j / k) for j in range(k)]
    if not closed: out.append(pts[-1])
    return out
def rdp(pts, eps=0.35):
    if len(pts) < 3: return pts
    (x1, y1), (x2, y2) = pts[0], pts[-1]; L = math.hypot(x2 - x1, y2 - y1) or 1e-9
    i, dmax = 0, 0
    for j in range(1, len(pts) - 1):
        d = abs((x2 - x1) * (y1 - pts[j][1]) - (x1 - pts[j][0]) * (y2 - y1)) / L
        if d > dmax: i, dmax = j, d
    return rdp(pts[:i + 1], eps)[:-1] + rdp(pts[i:], eps) if dmax > eps else [pts[0], pts[-1]]
def path(pts, closed=True):
    if closed:   # split the loop at its farthest point so neither half is degenerate
        m = max(range(len(pts)), key=lambda i: math.hypot(pts[i][0] - pts[0][0], pts[i][1] - pts[0][1]))
        pts = rdp(pts[:m + 1])[:-1] + rdp(pts[m:] + [pts[0]])[:-1]
    else:
        pts = rdp(pts)
    s = 'M' + 'L'.join(f'{x:.1f} {y:.1f}' for x, y in pts)
    return s + ('Z' if closed else '')
centre = [P(a, -90 + 72 * k) for k in range(5)]
seams, patches, inner, side = [], [], [], []
for k in range(5):
    th = -90 + 72 * k
    pc = P(D, th)
    verts = [P(b, th + 180 + 72 * j, *pc) for j in range(5)]   # verts[0] points at the centre
    inner.append(verts[0]); side.append((verts[1], verts[4]))
    patches.append(path([clamp(p) for p in dense(verts)]))
    seams.append(f'M{centre[k][0]:.1f} {centre[k][1]:.1f}L{verts[0][0]:.1f} {verts[0][1]:.1f}')
hexes = []
for k in range(5):
    s1 = side[k][0]; s2 = side[(k + 1) % 5][1]
    # pick the two facing side vertices (closest pair)
    cands = [(side[k][i], side[(k + 1) % 5][j]) for i in range(2) for j in range(2)]
    p, q = min(cands, key=lambda c: math.hypot(c[0][0] - c[1][0], c[0][1] - c[1][1]))
    pts = [clamp(t) for t in dense([p, q], closed=False)]
    pts = [t for t in pts if math.hypot(t[0] - cx, t[1] - cy) < rim - 0.01] or pts
    hexes.append(path(pts, closed=False))
print("    Ln('" + ' '.join(seams + hexes) + "', 4),")
print("    B('" + path(centre) + "'),")
print("    " + ', '.join(f"B('{p}')" for p in patches) + ",")
