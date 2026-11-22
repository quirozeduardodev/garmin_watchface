import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Menú de ajustes dentro del reloj: Carátula > Caratula Pro > Personalizar.
// Usa las mismas propiedades que los ajustes de Garmin Connect.
module CPSettings {
    // Orden de las opciones en el menú principal.
    const ITEMS = ["Style", "Accent", "Background", "Frames", "AvoidHands", "Seconds", "Extra", "RunGoal",
                   "Language", "HourFormat", "LeadingZero", "TempUnit", "DistUnit"];
    const GOALS = [10, 15, 20, 25, 30, 40, 50, 60, 80, 100, 150];

    function isToggle(key) {
        return key.equals("Frames") || key.equals("LeadingZero") || key.equals("AvoidHands");
    }

    function toggleTitle(key) {
        if (key.equals("Frames")) { return Rez.Strings.FramesTitle; }
        if (key.equals("AvoidHands")) { return Rez.Strings.AvoidTitle; }
        return Rez.Strings.LeadTitle;
    }

    // [título, etiquetas, valores] — valores null significa 0, 1, 2...
    function listDef(key) {
        if (key.equals("Style")) {
            return [Rez.Strings.StyleTitle, [Rez.Strings.S0, Rez.Strings.S1, Rez.Strings.S2, Rez.Strings.S3, Rez.Strings.S4, Rez.Strings.S5, Rez.Strings.S6, Rez.Strings.S7, Rez.Strings.S8, Rez.Strings.S9], null];
        } else if (key.equals("Accent")) {
            return [Rez.Strings.AccentTitle, [Rez.Strings.C0, Rez.Strings.C1, Rez.Strings.C2, Rez.Strings.C3, Rez.Strings.C4, Rez.Strings.C5, Rez.Strings.C6, Rez.Strings.C7, Rez.Strings.C8, Rez.Strings.C9, Rez.Strings.C10, Rez.Strings.C11, Rez.Strings.C12, Rez.Strings.C13, Rez.Strings.C14, Rez.Strings.C15, Rez.Strings.C16, Rez.Strings.C17, Rez.Strings.C18, Rez.Strings.C19], null];
        } else if (key.equals("Background")) {
            return [Rez.Strings.BgTitle, [Rez.Strings.BG0, Rez.Strings.BG1, Rez.Strings.BG2, Rez.Strings.BG3, Rez.Strings.BG4, Rez.Strings.BG5, Rez.Strings.BG6, Rez.Strings.BG7, Rez.Strings.BG8, Rez.Strings.BG9, Rez.Strings.BG10, Rez.Strings.BG11, Rez.Strings.BG12], null];
        } else if (key.equals("Seconds")) {
            return [Rez.Strings.SecondsTitle, [Rez.Strings.SEC0, Rez.Strings.SEC1, Rez.Strings.SEC2], null];
        } else if (key.equals("Extra")) {
            return [Rez.Strings.ExtraTitle, [Rez.Strings.X0, Rez.Strings.X1, Rez.Strings.X2, Rez.Strings.X3,
                Rez.Strings.X4, Rez.Strings.X5, Rez.Strings.X6, Rez.Strings.X7], null];
        } else if (key.equals("RunGoal")) {
            var labels = [];
            for (var i = 0; i < GOALS.size(); i++) {
                labels.add(GOALS[i].format("%d"));
            }
            return [Rez.Strings.RunGoalTitle, labels, GOALS];
        } else if (key.equals("Language")) {
            return [Rez.Strings.LangTitle, [Rez.Strings.LG0, Rez.Strings.LG1, Rez.Strings.LG2], null];
        } else if (key.equals("HourFormat")) {
            return [Rez.Strings.HourTitle, [Rez.Strings.HF0, Rez.Strings.HF1, Rez.Strings.HF2], null];
        } else if (key.equals("TempUnit")) {
            return [Rez.Strings.TempTitle, [Rez.Strings.TU0, Rez.Strings.TU1, Rez.Strings.TU2], null];
        }
        return [Rez.Strings.DistTitle, [Rez.Strings.DU0, Rez.Strings.DU1, Rez.Strings.DU2], null];
    }

    function text(x) {
        return (x instanceof String) ? x : WatchUi.loadResource(x);
    }

    function valueAt(def, i) {
        return (def[2] == null) ? i : def[2][i];
    }

    // Posición de la opción guardada actualmente (o -1 si no está en la lista).
    function currentIndex(key, def) {
        var v = Application.Properties.getValue(key);
        if (v == null) { return 0; }
        for (var i = 0; i < def[1].size(); i++) {
            if (valueAt(def, i) == v) { return i; }
        }
        return -1;
    }

    function currentLabel(key) {
        var def = listDef(key);
        var i = currentIndex(key, def);
        if (i < 0) {
            var v = Application.Properties.getValue(key);
            return (v == null) ? "" : v.toString();
        }
        return text(def[1][i]);
    }

    function boolValue(key) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? true : (v == true);
    }

    function applied() as Void {
        Application.getApp().onSettingsChanged();
    }
}

class CPSettingsMenu extends WatchUi.Menu2 {
    function initialize() {
        Menu2.initialize({:title => Rez.Strings.AppName});
        for (var i = 0; i < CPSettings.ITEMS.size(); i++) {
            var key = CPSettings.ITEMS[i];
            if (CPSettings.isToggle(key)) {
                addItem(new WatchUi.ToggleMenuItem(CPSettings.toggleTitle(key), null, key, CPSettings.boolValue(key), null));
            } else {
                addItem(new WatchUi.MenuItem(CPSettings.listDef(key)[0], CPSettings.currentLabel(key), key, null));
            }
        }
    }
}

class CPSettingsDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var key = item.getId();
        if (item instanceof WatchUi.ToggleMenuItem) {
            Application.Properties.setValue(key as String, (item as WatchUi.ToggleMenuItem).isEnabled());
            CPSettings.applied();
            return;
        }
        var def = CPSettings.listDef(key);
        var sub = new WatchUi.Menu2({:title => def[0]});
        for (var i = 0; i < def[1].size(); i++) {
            sub.addItem(new WatchUi.MenuItem(def[1][i], null, i, null));
        }
        var cur = CPSettings.currentIndex(key, def);
        if (cur >= 0) { sub.setFocus(cur); }
        WatchUi.pushView(sub, new CPOptionDelegate(key, item), WatchUi.SLIDE_LEFT);
    }
}

class CPOptionDelegate extends WatchUi.Menu2InputDelegate {
    var mKey;
    var mParent;

    function initialize(key, parentItem) {
        Menu2InputDelegate.initialize();
        mKey = key;
        mParent = parentItem;
    }

    function onSelect(item) {
        var def = CPSettings.listDef(mKey);
        var i = item.getId();
        Application.Properties.setValue(mKey, CPSettings.valueAt(def, i));
        mParent.setSubLabel(CPSettings.text(def[1][i]));
        CPSettings.applied();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
