// Copyright © 2020 Mark Summerfield. All rights reserved.

import gtk.ApplicationWindow: ApplicationWindow;

final class GameWindow : ApplicationWindow {
    import board: Board;
    import config: Config;
    import gdk.Event: Event;
    import gtk.Application: Application;
    import gtk.Label: Label;
    import gtk.ToolButton: ToolButton;
    import gtk.Widget: Widget;

    private {
        ToolButton newButton;
        ToolButton optionsButton;
        ToolButton helpButton;
        ToolButton aboutButton;
        ToolButton quitButton;
        Board board;
        Label statusLabel;
        bool terminating;
        Config cfg;
    }

    this(Application application) {
        import common: APPNAME, ICON;

        super(application);
        cfg = Config(application.getApplicationId);
        setTitle(APPNAME);
        setIconFromFile(ICON); // TODO embed or SVG
        makeWidgets;
        makeLayout;
        makeBindings;
        addOnKeyPress(&onKeyPress);
        setDefaultSize(cfg.width, cfg.height);
        if (cfg.x > 0 && cfg.y > 0)
            move(cfg.x, cfg.y);
        showAll;
        board.newGame;
    }

    private void makeWidgets() {
        import gtk.IconSize: IconSize;
        import gtk.Image: Image;
        import gtkc.gtktypes: StockID;

        newButton = new ToolButton(StockID.NEW);
        newButton.setTooltipMarkup("New <b>n</b>");
        optionsButton = new ToolButton(StockID.PREFERENCES);
        optionsButton.setTooltipMarkup("Options <b>o</b>");
        helpButton = new ToolButton(StockID.HELP);
        helpButton.setTooltipMarkup("Help <b>h</b> <i>or</i> <b>F1</b>");
        aboutButton = new ToolButton(StockID.ABOUT);
        aboutButton.setTooltipMarkup("About <b>a</b>");
        quitButton = new ToolButton(StockID.QUIT);
        quitButton.setTooltipMarkup("Quit <b>q</b> <i>or</i> <b>Esc</b>");
        board = new Board(cfg, &onChangeState);
        statusLabel = new Label("0/0");
    }

    private void makeLayout() {
        import gtk.Box: Box;
        import gtkc.gtktypes: GtkOrientation;

        enum pad = 1;
        enum: bool {Expand = true, Fill = true,
                    NoExpand = false, NoFill = false}
        auto leftBox = new Box(GtkOrientation.HORIZONTAL, pad);
        leftBox.setHomogeneous(true);
        leftBox.packStart(newButton, NoExpand, Fill, pad);
        leftBox.packStart(optionsButton, NoExpand, Fill, pad);
        leftBox.packStart(helpButton, NoExpand, Fill, pad);
        leftBox.packStart(aboutButton, NoExpand, Fill, pad);
        auto hbox = new Box(GtkOrientation.HORIZONTAL, pad);
        hbox.packStart(leftBox, NoExpand, NoFill, pad);
        hbox.packEnd(quitButton, NoExpand, Fill, pad);
        auto vbox = new Box(GtkOrientation.VERTICAL, pad);
        vbox.packStart(hbox, NoExpand, Fill, pad);
        vbox.packStart(board, Expand, Fill, pad);
        vbox.packEnd(statusLabel, NoExpand, Fill, pad);
        add(vbox);
    }

    private void makeBindings() {
        newButton.addOnClicked(&onNew);
        optionsButton.addOnClicked(&onOptions);
        helpButton.addOnClicked(&onHelp);
        aboutButton.addOnClicked(&onAbout);
        quitButton.addOnClicked(delegate void(ToolButton) { close; });
        addOnDestroy(&onQuit);
    }

    // These are application-global since we don't want a notion of focus
    private bool onKeyPress(Event event, Widget) {
        import gdk.Keymap : Keymap;

        uint kv;
        event.getKeyval(kv);
        switch (Keymap.keyvalName(kv)) {
        case "n", "N":
            onNew(null);
            return true;
        case "o", "O":
            onOptions(null);
            return true;
        case "h", "H", "F1":
            onHelp(null);
            return true;
        case "a", "A":
            onAbout(null);
            return true;
        case "q", "Q", "Escape":
            onQuit(null);
            return true;
        case "Left":
            board.navigate(Board.Direction.LEFT);
            return true;
        case "Right":
            board.navigate(Board.Direction.RIGHT);
            return true;
        case "Up":
            board.navigate(Board.Direction.UP);
            return true;
        case "Down":
            board.navigate(Board.Direction.DOWN);
            return true;
        case "space":
            board.chooseTile;
            return true;
        default:
            return false;
        }
    }

    private void onNew(ToolButton) {
        board.newGame;
    }

    private void onOptions(ToolButton) {
        import std.stdio: writeln;
        writeln("onOptions"); // TODO
    }

    private void onHelp(ToolButton) {
        import std.stdio: writeln;
        writeln("onHelp"); // TODO
    }

    private void onAbout(ToolButton) {
        import aboutbox: about;
        about(this);
    }

    private void onQuit(Widget) {
        if (terminating)
            return;
        terminating = true;
        int a;
        int b;
        getSize(a, b);
        cfg.setWidth(a);
        cfg.setHeight(b);
        getPosition(a, b);
        cfg.setX(a);
        cfg.setY(b);
        cfg.save;
        destroy;
    }

    private void onChangeState(int score, Board.State state) {
        import std.format: format;

        string message;
        if (state == Board.State.GAME_OVER)
            message = format("%,d Game Over", score);
        else if (state == Board.State.USER_WON) {
            if (score > cfg.highScore) {
                message = format("%,d New High Score!", score);
                cfg.setHighScore(score);
                cfg.save;
            } else
                message = format("%,d You Won!", score);
        } else // still playing
            message = format("%,d/%,d", score, cfg.highScore);
	    statusLabel.setText(message);
    }
}
