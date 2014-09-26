import csv
import json
import itertools


def load(fname):
    """as geojson"""
    with open(fname) as f:
        reader = csv.DictReader(f, delimiter=';')
        for d in reader:
            geom = json.loads(d.pop('geometry'))
            yield {'type': 'feature', 'geometry': geom, 'properties': d}


def to_screen(features, l, b, r, t, width, height):
    "as {styles, coords} list"
    tx = width / (r - l)
    ty = height / (t - b)
    features_by_layers = sorted((k, list(g)) for k, g in itertools.groupby(features, lambda x: x['properties']['layer']))
    #features_by_layers.reverse()
    lines = []
    for _, features in features_by_layers:
        inner = []
        casing = []
        for feature in features:
            inner_style = {'type': 'line', 'lineJoin': 'round', 'lineCap': 'round'}
            casing_style = {'type': 'line', 'lineJoin': 'round'}
            geom = feature['geometry']
            coords = list(map(int, ((x - l) * tx, (y - b) * ty)) for x, y in geom['coordinates'])
            # filter coords
            coords = list((x, y) for x, y in coords if 0 <= x < 65536 and 0 <= y <= 65536)
            
            #print coords
            # if not any(((0 < x < 1200) and (0 < y < 1200)) for x, y in coords):
            #     continue
            # if not feature['properties']['type'] == 'primary':
            #     continue
            properties = feature['properties']
            highway = properties['type']
            klass = properties['class']
        
            if highway == 'primary':
                inner.append(dict(line=coords, stroke=0, **inner_style))
                casing.append(dict(line=coords, stroke=1, **casing_style))
            elif highway == 'motorway':
                inner.append(dict(line=coords, stroke=2, **inner_style))
                casing.append(dict(line=coords, stroke=3, **casing_style))
            elif klass == 'railway':
                # use dash symbolizer
                inner.append(dict(line=coords, stroke=6))
            else:
                inner.append(dict(line=coords, stroke=4, **inner_style))
                casing.append(dict(line=coords, stroke=5, **casing_style))
        lines.extend(casing)
        lines.extend(inner)
    return lines


def packjson(fname, out, screen):
    features = load(fname)
    lines = list(to_screen(features, *screen))
    #lines.reverse()
    print("len(lines): %s" % len(lines))
    data = json.dumps(lines, separators=(',',':'))
    with open(out, 'wb') as f:
        f.write('var ROADS = ')
        f.write(data)
        f.write(';')
    

if __name__  == '__main__':
    packjson('roads.csv', 'roads.js', [-7910500.0, 5212900.0, -7909900.0, 5213500.0, 600.0, 600.0])
