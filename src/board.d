// Copyright © 2020 Mark Summerfield. All rights reserved.

import gtk.DrawingArea: DrawingArea;
import std.typecons: Tuple;

final class Board : DrawingArea {
    import cairo.Context: Context, Scoped;
    import color: Color;
    import gdk.Event: Event;
    import gtk.Widget: Widget;
    import options: Options;
    import point: Point;

    enum Direction { UP, DOWN, LEFT, RIGHT }
    enum State { PLAYING, GAME_OVER, USER_WON }

    private {
        alias Size = Tuple!(int, "width", int, "height");
        alias OnChangeStateFn = void delegate(int, State);

        OnChangeStateFn onChangeState;
        auto options = Options();
        State state;
        int score;
        Point selected;
        Color[][] tiles;
    }

    this(OnChangeStateFn onChangeState) {
        this.onChangeState = onChangeState;
        setSizeRequest(150, 150); // Minimum size
        addOnDraw(&onDraw);
        addOnButtonPress(&onMouseButtonPress);
        setRedrawOnAllocate(true);
        newGame();
    }

    void newGame() {
        import color: COLORS;
        import std.algorithm: each;
        import std.array: array;
        import std.random: choice, Random, randomSample, unpredictableSeed;

        state = State.PLAYING;
        score = 0;
        selected = Point();
        auto rnd = Random(unpredictableSeed);
        auto colors = COLORS.byKey.array.randomSample(
            options.maxColors, rnd);
        tiles = new Color[][](options.columns, options.rows);
        each!(t => tiles[t[0]][t[1]] = colors.array.choice(rnd))
             (allTilesRange());
        doDraw();
        onChangeState(score, state);
    }

    private auto allTilesRange() {
        import std.algorithm: cartesianProduct;
        import std.range: iota;
        return cartesianProduct(iota(options.columns), iota(options.rows));
    }

    private void doDraw(int delayMs = 0) {
        if (delayMs > 0) {
            import glib.Timeout: Timeout;
            new Timeout(delayMs, delegate bool() {
                queueDraw(); return false; }, false);
        } else
            queueDraw();
    }

    private bool onDraw(Scoped!Context context, Widget) {
        import std.algorithm: each, min;
        import std.conv: to;
        import std.math: round;

        immutable size = tileSize();
        immutable edge = round(min(size.width, size.height) / 9).to!int;
        each!(t => drawTile(context, t[0], t[1], size, edge))
             (allTilesRange());
        return true;
    }

    private Size tileSize() {
        return Size(getAllocatedWidth() / options.columns,
                    getAllocatedHeight() / options.rows);
    }

    private void drawTile(ref Scoped!Context context, const int x,
                          const int y, const Size size, const int edge) {
        immutable x1 = x * size.width;
        immutable y1 = y * size.height;
        immutable color = tiles[x][y];
        if (!color.isValid()) {
            context.rectangle(x1, y1, size.width, size.height);
            context.setSourceRgb(Color.BACKGROUND.toRgb.expand);
            context.fill();
        } else {
            import cairo.Pattern: Pattern;

            immutable edge2 = edge * 2;
            immutable x2 = x1 + size.width;
            immutable y2 = y1 + size.height;
            immutable colors = colorPair(color);
            drawSegments(context, edge, colors, x1, y1, x2, y2);
            auto gradient = Pattern.createLinear(x1, y1, x2, y2);
            gradient.addColorStopRgb(0, colors.light.toRgb.expand);
            gradient.addColorStopRgb(1, colors.dark.toRgb.expand);
            context.rectangle(x1 + edge, y1 + edge, size.width - edge2,
                              size.height - edge2);
            context.setSource(gradient);
            context.fill();
            if (selected.x == x && selected.y == y)
                drawFocus(context, x1, y1, size);
        }
    }

    private Color.Pair colorPair(Color color) {
        import color: COLORS;

        immutable plight = color in COLORS;
        Color light = plight is null ? Color.BACKGROUND : *plight;
        auto dark = color;
        if (state != State.PLAYING) {
            light = light.morphed(Color.DARKEN);
            dark = dark.morphed(Color.DARKEN);
        }
        return Color.Pair(light, dark);
    }

    private void drawSegments(ref Scoped!Context context, const int edge,
                              const Color.Pair colors, const int x1,
                              const int y1, const int x2, const int y2) {
        drawSegment(context, colors.light, [x1, y1, x1 + edge, y1 + edge,
                    x2 - edge, y1 + edge, x2, y1]); // top
        drawSegment(context, colors.light, [x1, y1, x1, y2, x1 + edge,
                    y2 - edge, x1 + edge, y1 + edge]); // left
        drawSegment(context, colors.dark, [x2 - edge, y1 + edge, x2, y1, x2,
                    y2, x2 - edge, y2 - edge]); // right
        drawSegment(context, colors.dark, [x1, y2, x1 + edge, y2 - edge,
                    x2 - edge, y2 - edge, x2, y2]); // bottom
    }

    private void drawSegment(ref Scoped!Context context, const Color color,
                             const int[] points) {
        context.newPath();
        context.moveTo(points[0], points[1]);
        for (int i = 2; i < points.length; i += 2)
            context.lineTo(points[i], points[i + 1]);
        context.closePath();
        context.setSourceRgb(color.toRgb.expand);
        context.fill();
    }

    private void drawFocus(ref Scoped!Context context, const int x1,
                           const int y1, const Size size) {
        import std.algorithm: min;
        import std.math: fmax, fmin;

        immutable indent = fmax(2, min(size.width, size.height) / 8.0);
        immutable indent2 = indent * 2.5;
        context.setDash([1.5], 0);
        context.rectangle(x1 + indent, y1 + indent, size.width - indent2,
                          size.height - indent2);
        context.setSourceRgb(Color.FOCUS_RECT.toRgb.expand);
        context.stroke();
    }

    private bool onMouseButtonPress(Event event, Widget) {
        if (state == State.PLAYING) {
            import std.conv: to;
            import std.math: floor;

            auto size = tileSize();
            double eventX;
            double eventY;
            event.getCoords(eventX, eventY);
            immutable x = floor(eventX / size.width).to!int;
            immutable y = floor(eventY / size.height).to!int;
            selected.clear();
            deleteTiles(Point(x, y));
        }
        return true;
    }

    void navigate(Direction direction) {
        if (state != State.PLAYING)
            return;
        if (!selected.isValid()) {
            selected.x = options.columns / 2;
            selected.y = options.rows / 2;
        } else {
            int x = selected.x;
            int y = selected.y;
            final switch (direction) {
            case Direction.LEFT: x--; break;
            case Direction.RIGHT: x++; break;
            case Direction.UP: y--; break;
            case Direction.DOWN: y++; break;
            }
            if (0 <= x && x < options.columns && 0 <= y && y < options.rows
                    && tiles[x][y].isValid()) {
                selected.x = x;
                selected.y = y;
            }
        }
        doDraw();
    }

    void chooseTile() {
        if (state != State.PLAYING || !selected.isValid())
            return;
        deleteTiles(selected);
    }

    private void deleteTiles(Point p) {
        auto color = tiles[p.x][p.y];
        if (!color.isValid() || !isLegal(p, color))
            return;
        // TODO
    }

    private bool isLegal(Point p, Color color) {
        immutable x = p.x;
        immutable y = p.y;
        if (x > 0 && color == tiles[x - 1][y])
            return true;
        if (x + 1 < options.columns && color == tiles[x + 1][y])
            return true;
        if (y > 0 && color == tiles[x][y - 1])
            return true;
        if (y + 1 < options.rows && color == tiles[x][y + 1])
            return true;
        return false;
    }
}