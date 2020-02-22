// Copyright © 2020 Mark Summerfield. All rights reserved.

struct Config {
    import color: COLORS;
    import glib.KeyFile: KeyFile;
    import std.algorithm: clamp;
    import std.conv: to;

    this(string applicationId) {
        import glib.Util: gutil = Util;
        import std.array: replace;
        import std.path: buildPath, dirSeparator;

        filename = buildPath(
                gutil.getUserConfigDir,
                applicationId.replace('.', dirSeparator) ~ ".ini");
        load();
    }

    int maxColors() const { return _maxColors; }

    void setMaxColors(int maxColors=DEF_MAXCOLORS, int low=2,
                      int high=COLORS.length.to!int) {
        _maxColors = clamp(maxColors, low, high);
    }

    int columns() const { return _columns; }

    void setColumns(int columns=DEF_COLUMNS, int low=5, int high=30) {
        _columns = clamp(columns, low, high);
    }

    int rows() const { return _rows; }

    void setRows(int rows=DEF_ROWS, int low=5, int high=30) {
        _rows = clamp(rows, low, high);
    }

    int delayMs() const { return _delayMs; }

    void setDelayMs(int delayMs=DEF_DELAYMS, int low=0, int high=1000) {
        _delayMs = clamp(delayMs, low, high);
    }

    int highScore() const { return _highScore; }

    void setHighScore(int highScore=DEF_HIGHSCORE, int low=0,
                      int high=int.max) {
        _highScore = clamp(highScore, low, high);
    }

    int x() const { return _x; }

    void setX(int x=DEF_X) {
        _x = x;
    }

    int y() const { return _y; }

    void setY(int y=DEF_Y) {
        _y = y;
    }

    int width() const { return _width; }

    void setWidth(int width=DEF_WIDTH, int low=200, int high=int.max) {
        _width = clamp(width, low, high);
    }

    int height() const { return _height; }

    void setHeight(int height=DEF_HEIGHT, int low=200, int high=int.max) {
        _height = clamp(height, low, high);
    }

    private void load() {
        assert(filename.length);

        import glib.c.types: GKeyFileFlags;

        auto keyFile = new KeyFile;
        if (!keyFile.loadFromFile(filename, GKeyFileFlags.KEEP_COMMENTS)) {
            import std.stdio: stderr;
            stderr.writeln("failed to load config");
            return;
        }
        setMaxColors(getInt(keyFile, BOARD, MAXCOLORS, DEF_MAXCOLORS));
        setColumns(getInt(keyFile, BOARD, COLUMNS, DEF_COLUMNS));
        setRows(getInt(keyFile, BOARD, ROWS, DEF_ROWS));
        setDelayMs(getInt(keyFile, BOARD, DELAYMS, DEF_DELAYMS));
        setHighScore(getInt(keyFile, BOARD, HIGHSCORE, DEF_HIGHSCORE));
        setX(getInt(keyFile, WINDOW, X, DEF_X));
        setY(getInt(keyFile, WINDOW, Y, DEF_Y));
        setWidth(getInt(keyFile, WINDOW, WIDTH, DEF_WIDTH));
        setHeight(getInt(keyFile, WINDOW, HEIGHT, DEF_HEIGHT));
    }

    private int getInt(ref KeyFile keyFile, string group, string key,
                       int def) {
        auto value = keyFile.getValue(group, key);
        if (value !is null) {
            import std.conv: ConvException;
            try {
                return value.to!int;
            } catch (ConvException) {
                // ignore and return default
            }
        }
        return def;
    }

    void save() {
        assert(filename.length);

        import glib.KeyFile: KeyFile;
        import std.file: exists, FileException, mkdirRecurse;
        import std.path: dirName;

        immutable path = dirName(filename);
        if (!path.exists)
            try {
                mkdirRecurse(path);
            } catch (FileException err) {
                import std.stdio: stderr;
                stderr.writefln("failed to create config path: %s", err);
                return;
            }
        auto keyFile = new KeyFile;
        keyFile.setInteger(BOARD, MAXCOLORS, maxColors);
        keyFile.setInteger(BOARD, COLUMNS, columns);
        keyFile.setInteger(BOARD, ROWS, rows);
        keyFile.setInteger(BOARD, DELAYMS, delayMs);
        keyFile.setInteger(BOARD, HIGHSCORE, highScore);
        keyFile.setInteger(WINDOW, X, x);
        keyFile.setInteger(WINDOW, Y, y);
        keyFile.setInteger(WINDOW, WIDTH, width);
        keyFile.setInteger(WINDOW, HEIGHT, height);
        if (!keyFile.saveToFile(filename)) {
            import std.stdio: stderr;
            stderr.writeln("failed to save config");
        }
    }

    private {
        enum BOARD = "Board";
        enum WINDOW = "Window";
        enum MAXCOLORS = "maxColors";
        enum COLUMNS = "columns";
        enum ROWS = "rows";
        enum DELAYMS = "delayMs";
        enum HIGHSCORE = "highScore";
        enum X = "x";
        enum Y = "y";
        enum WIDTH = "width";
        enum HEIGHT = "height";

        enum DEF_MAXCOLORS = 4;
        enum DEF_COLUMNS = 9;
        enum DEF_ROWS = 9;
        enum DEF_DELAYMS = 250;
        enum DEF_HIGHSCORE = 0;
        enum DEF_X = 0;
        enum DEF_Y = 0;
        enum DEF_WIDTH = 400;
        enum DEF_HEIGHT = 400;

        string filename;
        int _maxColors = DEF_MAXCOLORS;
        int _columns = DEF_COLUMNS;
        int _rows = DEF_ROWS;
        int _delayMs = DEF_DELAYMS;
        int _highScore = DEF_HIGHSCORE;
        int _x = DEF_X;
        int _y = DEF_Y;
        int _width = DEF_WIDTH;
        int _height = DEF_HEIGHT;
    }
}
