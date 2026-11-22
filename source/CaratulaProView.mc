import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

// Colores disponibles en la pantalla MIP del Forerunner 255.
const COL_W = 0xFFFFFF;
const COL_L = 0xAAAAAA;
const COL_G = 0x555555;
const COL_K = 0x000000;
const COL_RED = 0xFF0000;
const CX = 130;
const CY = 130;

// Índices de etiquetas traducidas (ver LBL_ES / LBL_EN).
const LB_STEPS_LOW = 0;
const LB_STEPS = 1;
const LB_HR = 2;
const LB_WEEK = 3;
const LB_STRESS = 4;
const LB_FLOORS = 5;
const LB_IMIN = 6;
const LB_NOTIF = 7;
const LB_BAT = 8;

class CaratulaProView extends WatchUi.WatchFace {
    var dc = null;
    var d;
    var awake = true;
    var style = 0;
    var ac = 0x55FF00;
    var frames = true;
    var runGoal = 30;
    var extra = 0;   // dato extra en las analógicas (0 = ninguno)
    var secMode = 0; // 0 = al levantar la muñeca, 1 = nunca
    var lang = 0;    // 0 = español, 1 = inglés
    var tempF = false;
    var distMi = false;
    var hourMode = 0; // 0 = automático, 1 = 24 h, 2 = 12 h
    var leadZero = true;
    var lastSlowMin = -1;
    var budgetExceeded = false;
    var avoidHands = true;
    var hAng = 0.0;     // ángulo de la manecilla de la hora
    var mAng = 0.0;     // ángulo del minutero
    var bufRef = null;   // búfer de la carátula para "segundos siempre"
    var lastBox = null;
    var secKind = 0;     // 0 = sin segundos, 1 = texto digital, 2 = segundero
    var secX = 0;
    var secY = 0;
    var secW = 0;
    var secH = 0;
    var secFont = Graphics.FONT_TINY;
    var secColor = 0xFFFFFF;
    var secLolli = false;
    var ti = null;   // hora actual (Gregorian.Info)
    var bg = 0;       // fondo (0 = negro)
    var bgBmp = null; // imagen del fondo cargada
    var sky = null;   // cielo dinámico

    const ACCENTS = [0x55FF00, 0xFFAA00, 0x00AAFF, 0xFF0055, 0xFFFF00, 0xFF55FF, 0xFFFFFF, 0x00FF00, 0xAAFF00, 0x00FFAA, 0x00FFFF, 0x55AAFF, 0x0055FF, 0xAA55FF, 0xFF00FF, 0xFF0000, 0xFF5555, 0xFF5500, 0xFFAA55, 0xAAAAAA];
    const DAYS_ES = ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"];
    const DAYS_EN = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
    const MONS_ES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"];
    const MONS_EN = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    // Etiquetas en el orden de las constantes LB_*
    const LBL_ES = ["pasos", "Pasos", "FC", "sem", "Estrés", "Pisos", "Min int", "Notif", "Bat"];
    const LBL_EN = ["steps", "Steps", "HR", "wk", "Stress", "Floors", "Int min", "Notif", "Bat"];
    const ROMAN = ["XII", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"];

    function initialize() {
        WatchFace.initialize();
        d = new FaceData();
        loadSettings();
    }

    function loadSettings() as Void {
        style = readNum("Style", 0);
        if (PREVIEW_STYLE >= 0) { style = PREVIEW_STYLE; }
        if (style < 0 || style > 9) { style = 0; }
        var a = readNum("Accent", 0);
        if (a < 0 || a >= ACCENTS.size()) { a = 0; }
        ac = ACCENTS[a];
        var f = Application.Properties.getValue("Frames");
        frames = (f == null) ? true : f;
        if (PREVIEW_FRAMES >= 0) { frames = (PREVIEW_FRAMES == 1); }
        runGoal = readNum("RunGoal", 30);
        if (runGoal <= 0) { runGoal = 30; }
        extra = readNum("Extra", 0);
        if (PREVIEW_EXTRA >= 0) { extra = PREVIEW_EXTRA; }
        secMode = readNum("Seconds", 0);
        if (PREVIEW_SEC >= 0) { secMode = PREVIEW_SEC; }
        if (secMode != 2) { bufRef = null; }
        budgetExceeded = false;
        hourMode = readNum("HourFormat", 0);
        avoidHands = readBool("AvoidHands", true);
        bg = readNum("Background", 0);
        if (PREVIEW_BG >= 0) { bg = PREVIEW_BG; }
        if (bg < 0 || bg > 12) { bg = 0; }
        // El cielo se prepara aquí (fuera del dibujo) para no tardar al pintar.
        if (bg < 11) {
            sky = null;
        } else {
            if (sky == null) { sky = new Sky(); }
            sky.useWeather = (bg == 12);
            sky.key = "";
        }
        bgBmp = null;
        leadZero = readBool("LeadingZero", true);
        updateLocale();
        lastSlowMin = -1;
    }

    // Idioma y unidades. Las opciones "automático" siguen al reloj, por eso
    // se recalcula también cada minuto.
    function updateLocale() as Void {
        var ds = System.getDeviceSettings();
        var lp = readNum("Language", 0);
        if (PREVIEW_LANG >= 0) { lp = PREVIEW_LANG; }
        if (lp == 1) {
            lang = 0;
        } else if (lp == 2) {
            lang = 1;
        } else {
            lang = ((ds has :systemLanguage) && ds.systemLanguage == System.LANGUAGE_SPA) ? 0 : 1;
        }
        var tp = readNum("TempUnit", 0);
        tempF = (tp == 2) || (tp == 0 && ds.temperatureUnits == System.UNIT_STATUTE);
        var dp = readNum("DistUnit", 0);
        distMi = (dp == 2) || (dp == 0 && ds.distanceUnits == System.UNIT_STATUTE);
    }

    function readNum(key, def) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? def : v.toNumber();
    }

    function readBool(key, def) {
        var v = Application.Properties.getValue(key);
        return (v == null) ? def : (v == true);
    }

    function lb(k) {
        return (lang == 1) ? LBL_EN[k] : LBL_ES[k];
    }

    function dayName() {
        return ((lang == 1) ? DAYS_EN : DAYS_ES)[ti.day_of_week - 1];
    }

    function onExitSleep() as Void {
        awake = true;
        WatchUi.requestUpdate();
    }

    function onEnterSleep() as Void {
        awake = false;
        WatchUi.requestUpdate();
    }

    function onUpdate(dcIn as Dc) as Void {
        dc = dcIn;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        ti = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        if (PREVIEW_HM >= 0) { ti.hour = PREVIEW_HM / 60; ti.min = PREVIEW_HM % 60; }
        mAng = (ti.min + ti.sec / 60.0) * 6;
        hAng = ((ti.hour % 12) + ti.min / 60.0) * 30;
        d.refreshFast();
        if (ti.min != lastSlowMin) {
            updateLocale();
            d.refreshSlow();
            lastSlowMin = ti.min;
        }
        // Con "segundos siempre" la carátula se pinta en un búfer, para poder
        // repintar cada segundo solo la zona del segundero.
        var always = (secMode == 2) && !budgetExceeded;
        var b = always ? getBuffer() : null;
        if (b != null) {
            dc = b.getDc();
            if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        }
        secKind = 0;
        drawBackground();

        switch (style) {
            case 0: faceA(); break;
            case 1: faceB(); break;
            case 2: faceE(); break;
            case 3: faceC(); break;
            case 4: faceK(); break;
            case 5: faceM(); break;
            case 6: faceT(); break;
            case 7: faceW(); break;
            case 8: faceX(); break;
            case 9: faceY(); break;
            default: faceA(); break;
        }

        if (b != null) {
            dcIn.drawBitmap(0, 0, b);
            dc = dcIn;
        }
        if (secKind != 0 && ((awake && secMode != 1) || b != null)) {
            // PREVIEW_PTEST: prueba del repintado parcial en el simulador.
            var shown = PREVIEW_PTEST ? (ti.sec + 30) % 60 : ti.sec;
            drawSec(shown);
            lastBox = secBox(shown);
        }
        dc = null;
        if (PREVIEW_PTEST) { onPartialUpdate(dcIn); }
    }

    // Cada segundo en bajo consumo, solo con "segundos siempre".
    function onPartialUpdate(dcIn as Dc) as Void {
        if (secMode != 2 || budgetExceeded || secKind == 0 || bufRef == null) { return; }
        var b = bufRef.get();
        if (b == null) { return; }
        var sec = System.getClockTime().sec;
        var nb = secBox(sec);
        var x = nb[0];
        var y = nb[1];
        var x2 = nb[0] + nb[2];
        var y2 = nb[1] + nb[3];
        if (lastBox != null) {
            if (lastBox[0] < x) { x = lastBox[0]; }
            if (lastBox[1] < y) { y = lastBox[1]; }
            if (lastBox[0] + lastBox[2] > x2) { x2 = lastBox[0] + lastBox[2]; }
            if (lastBox[1] + lastBox[3] > y2) { y2 = lastBox[1] + lastBox[3]; }
        }
        dcIn.setClip(x, y, x2 - x, y2 - y);
        dcIn.drawBitmap(0, 0, b);
        dc = dcIn;
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
        drawSec(sec);
        dc = null;
        dcIn.clearClip();
        lastBox = nb;
    }

    // Fondo: negro, color sólido o una imagen con la paleta del reloj.
    function drawBackground() as Void {
        if (bg >= 11) {
            if (sky == null) { sky = new Sky(); }
            sky.draw(dc, ti, d, awake, style <= 2);
            return;
        }
        dc.setColor(COL_K, (bg == 1) ? 0x000055 : COL_K);
        dc.clear();
        if (bg < 2) { return; }
        if (bgBmp == null) {
            var ids = [Rez.Drawables.Bg2, Rez.Drawables.Bg3, Rez.Drawables.Bg4, Rez.Drawables.Bg5, Rez.Drawables.Bg6,
                       Rez.Drawables.Bg7, Rez.Drawables.Bg8, Rez.Drawables.Bg9, Rez.Drawables.Bg10];
            bgBmp = WatchUi.loadResource(ids[bg - 2]);
        }
        dc.drawBitmap(0, 0, bgBmp);
    }

    function getBuffer() {
        if (bufRef != null) {
            var b = bufRef.get();
            if (b != null) { return b; }
        }
        if (!(Graphics has :createBufferedBitmap)) { return null; }
        bufRef = Graphics.createBufferedBitmap({:width => 260, :height => 260});
        return (bufRef == null) ? null : bufRef.get();
    }

    // ------------------------------------------------------------------
    // Utilidades de texto y formato
    // ------------------------------------------------------------------

    function tx(x, y, font, s, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function txL(x, y, font, s, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, s, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function nv(v) {
        return (v == null) ? "--" : v.format("%d");
    }

    function thousands(n) {
        var s = n.format("%d");
        if (n < 1000) { return s; }
        return (n / 1000).format("%d") + "," + (n % 1000).format("%03d");
    }

    function stepsShort() {
        if (d.steps < 1000) { return d.steps.format("%d"); }
        return (d.steps / 1000.0).format("%.1f") + "k";
    }

    function runText() {
        if (d.runDist == null) { return "--"; }
        return (d.runDist / (distMi ? 1609.344 : 1000.0)).format("%.1f");
    }

    function distUnit() {
        return distMi ? "mi" : "km";
    }

    function runLabel() {
        return distUnit() + " " + lb(LB_WEEK);
    }

    function tempText() {
        if (d.temp == null) { return "--°"; }
        var t = tempF ? d.temp * 9.0 / 5.0 + 32.0 : d.temp;
        return Math.round(t).toNumber().format("%d") + "°";
    }

    function hourText() {
        var h = ti.hour;
        var h24 = (hourMode == 1) || (hourMode == 0 && System.getDeviceSettings().is24Hour);
        if (!h24) {
            h = h % 12;
            if (h == 0) { h = 12; }
        }
        return h.format(leadZero ? "%02d" : "%d") + ":" + ti.min.format("%02d");
    }

    function dayShort() {
        return dayName() + " " + ti.day.format("%d");
    }

    function dateText() {
        if (lang == 1) {
            return dayName() + " " + MONS_EN[ti.month - 1] + " " + ti.day.format("%d");
        }
        return dayName() + " " + ti.day.format("%d") + " " + MONS_ES[ti.month - 1];
    }

    function sunText() {
        if (d.sunrise == null) { return tempText(); }
        return tempText() + "   " + d.sunrise + " - " + d.sunset;
    }

    function frac(v, goal) {
        if (v == null || goal == null || goal <= 0) { return 0.0; }
        var f = v.toFloat() / goal.toFloat();
        return (f > 1.0) ? 1.0 : ((f < 0.0) ? 0.0 : f);
    }

    // ------------------------------------------------------------------
    // Utilidades de dibujo. Los ángulos son "de reloj": 0 = 12 en punto,
    // crecen en sentido horario.
    // ------------------------------------------------------------------

    function px(a, r) {
        var t = Math.toRadians(a);
        return [CX + Math.sin(t) * r, CY - Math.cos(t) * r];
    }

    function line(x1, y1, x2, y2, col, w) {
        dc.setPenWidth(w);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawLine(x1, y1, x2, y2);
    }

    function radial(a, r1, r2, col, w) {
        var p1 = px(a, r1);
        var p2 = px(a, r2);
        line(p1[0], p1[1], p2[0], p2[1], col, w);
    }

    function norm(g) {
        while (g < 0) { g += 360; }
        while (g >= 360) { g -= 360; }
        return g;
    }

    function arcAt(x, y, r, a0, sweep, col, w) {
        if (sweep < 1) { return; }
        dc.setPenWidth(w);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        if (sweep >= 359.5) {
            dc.drawCircle(x, y, r);
            return;
        }
        dc.drawArc(x, y, r, Graphics.ARC_CLOCKWISE, norm(90 - a0), norm(90 - a0 - sweep));
    }

    function arcCW(r, a0, sweep, col, w) {
        arcAt(CX, CY, r, a0, sweep, col, w);
    }

    function dot(x, y, r, col) {
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, r);
    }

    function bat(cx, y) {
        var x = cx - 15;
        var p = d.bat / 100.0;
        dc.setPenWidth(1);
        dc.setColor(COL_W, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x - 9, y - 5, 19, 11);
        dc.fillRectangle(x + 10, y - 2, 2, 5);
        dc.setColor((p < 0.2) ? COL_RED : ac, Graphics.COLOR_TRANSPARENT);
        var w = (15 * p).toNumber();
        if (w < 1) { w = 1; }
        dc.fillRectangle(x - 7, y - 3, w, 7);
        txL(x + 15, y, Graphics.FONT_XTINY, d.bat.format("%d") + "%", COL_W);
    }

    function sun(x, y, col) {
        dot(x, y, 4, col);
        for (var i = 0; i < 8; i++) {
            var t = Math.toRadians(i * 45);
            line(x + Math.cos(t) * 6, y + Math.sin(t) * 6, x + Math.cos(t) * 9, y + Math.sin(t) * 9, col, 2);
        }
    }

    function cloud(x, y) {
        dot(x - 5, y + 3, 5, COL_W);
        dot(x + 1, y - 1, 6, COL_W);
        dot(x + 7, y + 3, 5, COL_W);
        dc.fillRectangle(x - 5, y + 3, 13, 5);
    }

    function weatherIcon(x, y) {
        var c = d.cond;
        if (c == null) {
            cloud(x, y);
            return;
        }
        if (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR || c == Weather.CONDITION_FAIR) {
            sun(x, y, ac);
        } else if (c == Weather.CONDITION_PARTLY_CLOUDY || c == Weather.CONDITION_PARTLY_CLEAR) {
            sun(x + 4, y - 4, ac);
            cloud(x, y);
        } else {
            cloud(x, y);
        }
    }

    function mail(x, y, col) {
        dc.setPenWidth(1);
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.drawRectangle(x - 9, y - 6, 18, 12);
        dc.drawLine(x - 9, y - 6, x, y + 1);
        dc.drawLine(x, y + 1, x + 9, y - 6);
    }

    function dateBox(x, y, w, s, col) {
        if (frames) {
            dc.setPenWidth(1);
            dc.setColor(col, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(x - w / 2, y - 11, w, 22);
            dc.drawRectangle(x - w / 2 + 1, y - 10, w - 2, 20);
        }
        tx(x, y, Graphics.FONT_XTINY, s, frames ? COL_W : ac);
    }

    function cell(x, y, label, value, font) {
        tx(x, y, Graphics.FONT_XTINY, label, COL_L);
        tx(x, y + 18, font, value, COL_W);
    }

    function ring(x, y, r, p, value, label) {
        arcAt(x, y, r, 0, 360, COL_G, 5);
        arcAt(x, y, r, 0, 360 * p, ac, 5);
        tx(x, y, Graphics.FONT_TINY, value, COL_W);
        tx(x, y + r + 13, Graphics.FONT_XTINY, label, COL_L);
    }

    // Hora digital centrada; deja espacio para los segundos, que solo
    // se ven con la muñeca levantada.
    function digitalTime(y, fTime, fSec, secCol) {
        var t = hourText();
        var tw = dc.getTextWidthInPixels(t, fTime);
        var sw = dc.getTextWidthInPixels("88", fSec);
        var x0 = CX - (tw + 4 + sw) / 2;
        var hT = dc.getFontHeight(fTime);
        var hS = dc.getFontHeight(fSec);
        dc.setColor(COL_W, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x0, y - hT / 2, fTime, t, Graphics.TEXT_JUSTIFY_LEFT);
        // Los segundos se dibujan después, en drawSec().
        secKind = 1;
        secX = (x0 + tw + 4).toNumber();
        secY = (y + hT / 2 - hS - hT / 10).toNumber();
        secW = sw + 2;
        secH = hS;
        secFont = fSec;
        secColor = secCol;
    }

    // Marcas de minutos y horas en el borde.
    function ticks(r2, mLen, mCol, mW, hLen, hCol, hW) {
        for (var i = 0; i < 60; i++) {
            if (i % 5 == 0) {
                radial(i * 6, r2 - hLen, r2, hCol, hW);
            } else if (mLen > 0) {
                radial(i * 6, r2 - mLen, r2, mCol, mW);
            }
        }
    }

    function nums(r, font, skip, font12, labels) {
        for (var h = 1; h <= 12; h++) {
            if (skip.indexOf(h) >= 0) { continue; }
            var p = px(h * 30, r);
            var s = (labels == null) ? h.format("%d") : labels[h % 12];
            tx(p[0], p[1], (h == 12 && font12 != null) ? font12 : font, s, COL_W);
        }
    }

    function triangle12() {
        dc.setColor(ac, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([[130, 21], [123, 7], [137, 7]]);
        dot(116, 9, 2, COL_W);
        dot(144, 9, 2, COL_W);
    }

    function taper(a, len, w, col, tail) {
        var t = Math.toRadians(a);
        var dx = Math.sin(t);
        var dy = -Math.cos(t);
        var qx = Math.cos(t);
        var qy = Math.sin(t);
        var bx = CX - dx * tail;
        var by = CY - dy * tail;
        var mx = CX + dx * len * 0.85;
        var my = CY + dy * len * 0.85;
        var h = w / 2.0;
        var b = w / 3.0;
        dc.setColor(col, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon([
            [bx + qx * b, by + qy * b],
            [CX + qx * h, CY + qy * h],
            [mx + qx * h, my + qy * h],
            [CX + dx * len, CY + dy * len],
            [mx - qx * h, my - qy * h],
            [CX - qx * h, CY - qy * h],
            [bx - qx * b, by - qy * b]
        ]);
    }

    function hands(hw, mw, lolli) {
        var m = ti.min + ti.sec / 60.0;
        var h = (ti.hour % 12) + m / 60.0;
        taper(h * 30, 60, hw, COL_W, 10);
        taper(m * 6, 96, mw, COL_W, 12);
        dot(CX, CY, 6, ac);
        dot(CX, CY, 2, COL_K);
        // El segundero se dibuja después, en drawSec().
        secKind = 2;
        secLolli = lolli;
    }

    // Dibuja los segundos (texto o segundero) sobre lo ya dibujado.
    function drawSec(sec) {
        if (secKind == 1) {
            dc.setColor(secColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(secX, secY, secFont, sec.format("%02d"), Graphics.TEXT_JUSTIFY_LEFT);
        } else if (secKind == 2) {
            var s = sec * 6;
            var p1 = px(s + 180, 22);
            var p2 = px(s, 106);
            line(p1[0], p1[1], p2[0], p2[1], ac, 2);
            if (secLolli) {
                var p3 = px(s, 88);
                dot(p3[0], p3[1], 5, ac);
            }
            dot(CX, CY, 6, ac);
            dot(CX, CY, 2, COL_K);
        }
    }

    // Rectángulo [x, y, ancho, alto] que ocupan los segundos.
    function secBox(sec) {
        if (secKind == 1) {
            return [secX - 1, secY, secW, secH];
        }
        var s = sec * 6;
        var p1 = px(s + 180, 22);
        var p2 = px(s, 106);
        var x1 = (p1[0] < p2[0]) ? p1[0] : p2[0];
        var x2 = (p1[0] < p2[0]) ? p2[0] : p1[0];
        var y1 = (p1[1] < p2[1]) ? p1[1] : p2[1];
        var y2 = (p1[1] < p2[1]) ? p2[1] : p1[1];
        if (x1 > CX - 7) { x1 = CX - 7; }
        if (x2 < CX + 7) { x2 = CX + 7; }
        if (y1 > CY - 7) { y1 = CY - 7; }
        if (y2 < CY + 7) { y2 = CY + 7; }
        var m = secLolli ? 7 : 3;
        return [(x1 - m).toNumber(), (y1 - m).toNumber(), (x2 - x1 + 2 * m + 1).toNumber(), (y2 - y1 + 2 * m + 1).toNumber()];
    }

    // ------------------------------------------------------------------
    // Carátulas digitales
    // ------------------------------------------------------------------

    // A · Pulso
    function faceA() {
        // Arco superior: Body Battery. Arco inferior: pasos. 10 segmentos cada uno.
        segArc(121, 300, 120, frac(d.bb, 100), false);
        segArc(121, 240, 120, frac(d.steps, d.stepGoal), true);

        bat(100, 40);
        mail(150, 40, COL_L);
        txL(164, 40, Graphics.FONT_XTINY, d.notif.format("%d"), COL_W);
        tx(CX, 70, Graphics.FONT_TINY, dateText(), ac);
        digitalTime(122, Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_MILD, COL_W);

        line(50, 160, 210, 160, COL_G, 1);
        line(100, 168, 100, 200, COL_G, 1);
        line(160, 168, 160, 200, COL_G, 1);
        cell(70, 172, lb(LB_HR), nv(d.hr), Graphics.FONT_SMALL);
        cell(CX, 172, runLabel(), runText(), Graphics.FONT_SMALL);
        cell(190, 172, "kcal", nv(d.kcal), Graphics.FONT_SMALL);
        tx(CX, 224, Graphics.FONT_XTINY, thousands(d.steps) + " " + lb(LB_STEPS_LOW), ac);
    }

    // Arco dividido en 10 segmentos. reverse = se llena en sentido antihorario.
    function segArc(r, a0, total, p, reverse) {
        var n = 10;
        var seg = total / 10.0;
        var on = (p * n + 0.5).toNumber();
        if (p > 0 && on == 0) { on = 1; }
        for (var i = 0; i < n; i++) {
            var start = reverse ? (a0 - (i + 1) * seg) : (a0 + i * seg);
            arcCW(r, start + 1.5, seg - 3, (i < on) ? ac : COL_G, 8);
        }
    }
    // B · Anillos
    function faceB() {
        bat(CX, 24);
        tx(CX, 46, Graphics.FONT_XTINY, sunText(), COL_L);
        digitalTime(100, Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_MILD, COL_W);
        tx(CX, 144, Graphics.FONT_TINY, dateText(), ac);
        ring(72, 188, 23, frac(d.steps, d.stepGoal), stepsShort(), lb(LB_STEPS));
        ring(CX, 194, 23, frac(d.bb, 100), nv(d.bb), "Body Bat.");
        ring(188, 188, 23, frac(d.runDist, runGoal), runText(), runLabel());
    }

    // E · Tablero
    function faceE() {
        bat(92, 28);
        txL(134, 28, Graphics.FONT_XTINY, (d.phone ? "BT · " : "") + d.notif.format("%d") + " notif", COL_L);
        tx(CX, 48, Graphics.FONT_XTINY, sunText(), ac);
        digitalTime(92, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MILD, COL_W);
        tx(CX, 130, Graphics.FONT_TINY, dateText(), ac);

        cell(56, 152, lb(LB_HR), nv(d.hr), Graphics.FONT_TINY);
        cell(104, 152, "BB", nv(d.bb), Graphics.FONT_TINY);
        cell(156, 152, lb(LB_STRESS), nv(d.stress), Graphics.FONT_TINY);
        cell(204, 152, "SpO2", (d.spo2 == null) ? "--" : d.spo2.format("%d") + "%", Graphics.FONT_TINY);
        cell(78, 192, "kcal", nv(d.kcal), Graphics.FONT_TINY);
        cell(CX, 192, lb(LB_FLOORS), nv(d.floors), Graphics.FONT_TINY);
        cell(182, 192, lb(LB_IMIN), nv(d.imin), Graphics.FONT_TINY);

        line(80, 236, 180, 236, COL_G, 6);
        var w = 100 * frac(d.steps, d.stepGoal);
        if (w >= 1) { line(80, 236, 80 + w, 236, ac, 6); }
        tx(CX, 249, Graphics.FONT_XTINY, thousands(d.steps), COL_L);
    }

    // ------------------------------------------------------------------
    // Carátulas analógicas
    // ------------------------------------------------------------------

    // Dato extra elegido en Ajustes: [etiqueta, valor] o null.
    function extraInfo() {
        switch (extra) {
            case 1: return [lb(LB_HR), nv(d.hr)];
            case 2: return ["BB", nv(d.bb)];
            case 3: return [lb(LB_STEPS), thousands(d.steps)];
            case 4: return [lb(LB_NOTIF), d.notif.format("%d")];
            case 5: return [runLabel(), runText()];
            case 6: return ["kcal", nv(d.kcal)];
            case 7: return [lb(LB_STRESS), nv(d.stress)];
        }
        return null;
    }

    // Dato extra en una línea centrada: etiqueta gris y valor blanco.
    function extraLine(x, y) {
        var e = extraInfo();
        if (e == null) { return; }
        var f = Graphics.FONT_XTINY;
        var lw = dc.getTextWidthInPixels(e[0] + " ", f);
        var vw = dc.getTextWidthInPixels(e[1], f);
        var x0 = x - (lw + vw) / 2;
        txL(x0, y, f, e[0] + " ", COL_L);
        txL(x0 + lw, y, f, e[1], COL_W);
    }

    // Dato extra en dos líneas, para los costados.
    function extraStack(x, y) {
        var e = extraInfo();
        if (e == null) { return; }
        tx(x, y - 9, Graphics.FONT_XTINY, e[0], COL_L);
        tx(x, y + 9, Graphics.FONT_TINY, e[1], COL_W);
    }

    function weatherLine(x, y) {
        weatherIcon(x - 14, y);
        txL(x + 2, y, Graphics.FONT_XTINY, tempText(), COL_W);
    }

    function weatherStack(x, y) {
        weatherIcon(x, y - 9);
        tx(x, y + 12, Graphics.FONT_XTINY, tempText(), COL_W);
    }


    // ------------------------------------------------------------------
    // Distribución común de las analógicas: batería arriba, fecha a la
    // derecha, clima a la izquierda y el dato extra abajo. Si una manecilla
    // tapa un dato, el dato se recorre por el círculo para no quedar oculto.
    // ------------------------------------------------------------------

    function angDist(a, b) {
        var d = a - b;
        while (d < -180) { d += 360; }
        while (d > 180) { d -= 360; }
        return (d < 0) ? -d : d;
    }

    // Posición de un dato que normalmente va en el ángulo "base" a radio r.
    function slot(base, r) {
        var a = base;
        if (avoidHands) {
            var cands = [0, 35, -35, 55, -55];
            var bestD = -1;
            for (var i = 0; i < cands.size(); i++) {
                var c = base + cands[i];
                var dh = angDist(c, hAng);
                var dm = angDist(c, mAng);
                var dmin = (dh < dm) ? dh : dm;
                if (dmin >= 24) {
                    a = c;
                    break;
                }
                if (dmin > bestD) {
                    bestD = dmin;
                    a = c;
                }
            }
        }
        return px(a, r);
    }

    // longDate: "Sá 21" en vez de "21". boxed: fecha dentro de un marco.
    function analogData(longDate, boxed) {
        var sb = slot(0, 62);
        bat(sb[0], sb[1]);

        var sd = slot(90, longDate ? 56 : 60);
        var ds = longDate ? dayName().substring(0, 2) + " " + ti.day.format("%d") : ti.day.format("%d");
        if (boxed) {
            dateBox(sd[0], sd[1], longDate ? 46 : 32, ds, ac);
        } else {
            tx(sd[0], sd[1], Graphics.FONT_TINY, ds, ac);
        }

        var sw = slot(270, 62);
        weatherStack(sw[0], sw[1]);

        if (extraInfo() != null) {
            var se = slot(180, 60);
            extraLine(se[0], se[1]);
        }
    }

    // Cronógrafo: subesferas fijas — clima, fecha y batería.
    function faceC() {
        ticks(124, 6, COL_G, 2, 10, COL_W, 4);
        nums(98, Graphics.FONT_TINY, [], Graphics.FONT_SMALL, null);
        extraLine(CX, 70);

        arcAt(78, 136, 24, 0, 360, COL_G, 2);
        weatherIcon(78, 129);
        tx(78, 148, Graphics.FONT_XTINY, tempText(), COL_W);

        arcAt(182, 136, 24, 0, 360, COL_G, 2);
        tx(182, 128, Graphics.FONT_XTINY, dayName(), COL_L);
        tx(182, 144, Graphics.FONT_TINY, ti.day.format("%d"), ac);

        arcAt(CX, 188, 24, 0, 360, COL_G, 2);
        arcAt(CX, 188, 24, 0, 3.6 * d.bat, (d.bat < 20) ? COL_RED : ac, 4);
        tx(CX, 184, Graphics.FONT_XTINY, d.bat.format("%d") + "%", COL_W);
        tx(CX, 199, Graphics.FONT_XTINY, lb(LB_BAT), COL_L);
        hands(8, 5, false);
    }

    // Clásico
    function faceK() {
        ticks(124, 6, COL_G, 2, 13, COL_W, 4);
        nums(98, Graphics.FONT_TINY, [], Graphics.FONT_SMALL, null);
        analogData(true, true);
        hands(10, 7, false);
    }

    // Aviador
    function faceM() {
        ticks(124, 8, COL_W, 1, 12, COL_W, 3);
        triangle12();
        nums(98, Graphics.FONT_TINY, [], Graphics.FONT_SMALL, null);
        analogData(false, true);
        hands(12, 9, true);
    }

    // Esencial
    function faceT() {
        ticks(124, 5, COL_G, 1, 10, COL_W, 3);
        nums(98, Graphics.FONT_TINY, [], Graphics.FONT_SMALL, null);
        analogData(true, false);
        hands(8, 5, false);
    }


    // Romano
    function faceW() {
        ticks(124, 5, COL_G, 1, 9, COL_W, 3);
        nums(98, Graphics.FONT_TINY, [], Graphics.FONT_SMALL, ROMAN);
        analogData(true, true);
        hands(9, 6, false);
    }

    // Bisel: números sobre un anillo gris en el borde.
    function faceX() {
        dc.setPenWidth(22);
        dc.setColor(COL_G, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(CX, CY, 117);
        for (var h = 1; h <= 12; h++) {
            var p = px(h * 30, 117);
            tx(p[0], p[1], Graphics.FONT_TINY, h.format("%d"), (h % 3 == 0) ? ac : COL_W);
        }
        for (var i = 0; i < 60; i++) {
            if (i % 5 != 0) { radial(i * 6, 98, 104, COL_L, 1); }
        }
        analogData(false, true);
        hands(9, 6, false);
    }

    // Militar: pista de minutos tipo "riel".
    function faceY() {
        dc.setPenWidth(1);
        dc.setColor(COL_L, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(CX, CY, 124);
        dc.drawCircle(CX, CY, 116);
        for (var i = 0; i < 60; i++) {
            if (i % 5 == 0) {
                radial(i * 6, 112, 126, COL_W, 4);
            } else {
                radial(i * 6, 116, 124, COL_L, 1);
            }
        }
        nums(98, Graphics.FONT_TINY, [], Graphics.FONT_SMALL, null);
        analogData(false, false);
        hands(10, 7, true);
    }

}
