import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Weather;

// ----------------------------------------------------------------------
// Fondo dinámico: un cielo sincronizado con la realidad.
//  - Color del cielo según la hora real de amanecer/atardecer.
//  - Sol y luna en su posición en el cielo (salen por la izquierda/este
//    y se ponen por la derecha/oeste).
//  - Fase lunar real; la luna sale y se pone según su fase, así que hay
//    noches sin luna.
//  - Estrellas solo con cielo despejado; menos estrellas con luna llena.
//  - Vía Láctea en noches sin luna, constelación del mes.
//  - Nubes, lluvia, nieve, niebla y tormenta según el clima.
//  - Colinas en el horizonte con el color de la estación.
// El cielo se dibuja una vez en un búfer y solo se rehace cuando algo
// cambia (cada pocos minutos), así casi no consume batería.
// ----------------------------------------------------------------------

// Fases del cielo
const SK_NIGHT = 0;
const SK_DAWN = 1;     // alba (antes de que salga el sol)
const SK_SUNRISE = 2;  // amanecer
const SK_DAY = 3;
const SK_GOLDEN = 4;   // hora dorada
const SK_SUNSET = 5;   // puesta de sol
const SK_DUSK = 6;     // anochecer

// Clima simplificado
const WX_CLEAR = 0;
const WX_PARTLY = 1;
const WX_CLOUDY = 2;
const WX_RAIN = 3;
const WX_STORM = 4;
const WX_SNOW = 5;
const WX_FOG = 6;

const NEW_MOON_REF = 947182440;   // luna nueva: 6 ene 2000 18:14 UTC
const SYNODIC = 29.530588853;     // días de un ciclo lunar
const MOON_HALF = 372;            // minutos que la luna pasa sobre el horizonte, a cada lado del tránsito
const STAR_COUNT = 170;

// Constelaciones: puntos (x, y en 0..100), brillo (2 = brillante), líneas.
const CONST_PTS = [
    // ene · Orión
    [[50, 0, 1], [24, 16, 2], [72, 20, 1], [42, 50, 1], [50, 47, 1], [58, 44, 1], [30, 88, 1], [80, 82, 2]],
    // feb · Can Mayor
    [[55, 14, 2], [86, 20, 1], [40, 4, 1], [42, 58, 1], [28, 88, 1], [10, 55, 1], [60, 40, 1]],
    // mar · Géminis
    [[18, 4, 2], [46, 8, 2], [26, 36, 1], [38, 62, 1], [48, 94, 1], [56, 34, 1], [70, 60, 1], [84, 86, 1]],
    // abr · Leo
    [[74, 78, 2], [80, 56, 1], [64, 40, 1], [70, 24, 1], [86, 14, 1], [96, 30, 1], [34, 42, 1], [4, 56, 1], [36, 66, 1]],
    // may · Osa Mayor
    [[0, 26, 1], [20, 14, 1], [36, 20, 1], [52, 32, 1], [82, 18, 2], [88, 54, 1], [56, 62, 1]],
    // jun · Boyero
    [[50, 96, 2], [66, 64, 1], [72, 30, 1], [52, 4, 1], [30, 34, 1], [34, 62, 1]],
    // jul · Escorpión
    [[76, 4, 1], [80, 18, 1], [76, 32, 1], [56, 22, 1], [42, 30, 2], [36, 46, 1], [30, 60, 1], [30, 76, 1], [40, 90, 1], [56, 96, 1], [68, 88, 1], [64, 76, 1]],
    // ago · Cisne
    [[50, 0, 2], [50, 34, 1], [50, 62, 1], [50, 96, 1], [14, 42, 1], [86, 24, 1]],
    // sep · Sagitario (la tetera)
    [[4, 52, 1], [26, 44, 1], [26, 76, 1], [40, 22, 1], [56, 44, 1], [56, 70, 1], [86, 34, 1], [86, 66, 1]],
    // oct · Pegaso
    [[30, 28, 1], [76, 28, 1], [76, 74, 1], [30, 74, 2], [14, 90, 1], [0, 80, 1], [12, 14, 1], [0, 24, 1]],
    // nov · Casiopea
    [[0, 30, 1], [26, 66, 1], [50, 44, 2], [74, 70, 1], [100, 34, 1]],
    // dic · Tauro y las Pléyades
    [[66, 60, 1], [56, 50, 1], [46, 44, 1], [8, 12, 1], [56, 70, 1], [44, 74, 2], [14, 60, 1], [88, 26, 1], [92, 22, 1], [94, 28, 1], [90, 31, 1]]
];
const CONST_LINES = [
    [[0, 1], [0, 2], [1, 3], [2, 5], [3, 4], [4, 5], [3, 6], [5, 7]],
    [[1, 0], [0, 2], [0, 6], [6, 3], [3, 4], [3, 5]],
    [[0, 1], [0, 2], [2, 3], [3, 4], [1, 5], [5, 6], [6, 7]],
    [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [2, 6], [6, 7], [7, 8], [8, 0], [6, 8]],
    [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 6], [6, 3]],
    [[0, 1], [1, 2], [2, 3], [3, 4], [4, 5], [5, 0]],
    [[0, 1], [1, 2], [1, 3], [3, 4], [4, 5], [5, 6], [6, 7], [7, 8], [8, 9], [9, 10], [10, 11]],
    [[0, 1], [1, 2], [2, 3], [4, 1], [1, 5]],
    [[0, 1], [0, 2], [1, 2], [1, 3], [3, 4], [1, 4], [4, 5], [5, 2], [4, 6], [6, 7], [7, 5]],
    [[0, 1], [1, 2], [2, 3], [3, 0], [3, 4], [4, 5], [0, 6], [6, 7]],
    [[0, 1], [1, 2], [2, 3], [3, 4]],
    [[0, 1], [1, 2], [2, 3], [0, 4], [4, 5], [5, 6]]
];

// Centro de cada constelación en el cielo real: [ascensión recta (h), declinación (°)].
const CONST_CENTER = [[5.6, 5.0], [6.9, -22.0], [7.1, 23.0], [10.7, 15.0], [11.5, 55.0], [14.7, 30.0],
                      [16.9, -30.0], [20.6, 42.0], [19.0, -28.0], [22.7, 20.0], [1.0, 60.0], [4.5, 18.0]];

class Sky {
    var bufRef = null;
    var key = "";
    // Catálogo de estrellas en coordenadas del cielo (radianes): fijo,
    // como el cielo real; lo que cambia es cómo se ve desde tu lugar y hora.
    // Se guardan senos y cosenos ya calculados para que el reloj no tarde.
    var cRA = [];
    var sRA = [];
    var cDe = [];
    var sDe = [];
    var mcRA = [];      // Vía Láctea (sobre el plano real de la galaxia)
    var msRA = [];
    var mcDe = [];
    var msDe = [];
    var hillFar = null;
    var hillNear = null;
    var mwCore = [];
    var visX = [];      // estrellas visibles ahora (para que titilen)
    var visY = [];
    var lst = 0.0;      // tiempo sidéreo local (radianes)
    var sinLat = 0.37;
    var cosLat = 0.93;
    var lonDeg = -101.0;
    var tMin = 0;       // minutos desde 1970 (para mover las nubes)
    var doyNow = 1;
    var yearNow = 2026;
    var windVx = 0.25;  // velocidad de las nubes en pantalla (px/min, + = derecha)
    // Estado calculado en update()
    var phase = SK_NIGHT;
    var wx = WX_CLEAR;
    var season = 0;     // 0 primavera, 1 verano, 2 otoño, 3 invierno
    var south = false;
    var moonP = 0.0;    // fase 0..1 (0 nueva, 0.5 llena)
    var moonUp = false;
    var moonAng = 0.0;
    var sunUp = false;
    var sunAng = 0.0;
    var month = 1;
    var showStars = false;
    var cloudX = [];    // posición de las nubes (lluvia y nieve caen de ellas)
    var cloudY = [];

    function initialize() {
        // Estrellas repartidas por toda la esfera celeste.
        var seed = 1234;
        for (var i = 0; i < STAR_COUNT; i++) {
            seed = (seed * 75 + 74) % 65537;
            var ra = seed / 65537.0 * 2 * Math.PI;
            seed = (seed * 75 + 74) % 65537;
            var sd = seed / 65537.0 * 2 - 1;
            cRA.add(Math.cos(ra));
            sRA.add(Math.sin(ra));
            sDe.add(sd);
            cDe.add(Math.sqrt(1 - sd * sd));
        }
        // Vía Láctea: puntos cerca del plano galáctico, más densos hacia el
        // centro de la galaxia (en Sagitario). Se convierten a AR/Dec.
        var aN = Math.toRadians(192.85948);
        var dN = Math.toRadians(27.12825);
        var lN = Math.toRadians(122.93192);
        seed = 4321;
        for (var i = 0; i < 200; i++) {
            seed = (seed * 75 + 74) % 65537;
            var u = seed / 65537.0;
            var l = (i % 5 < 3) ? (u - 0.5) * 120.0 : (u - 0.5) * 360.0;
            seed = (seed * 75 + 74) % 65537;
            var r1 = seed / 65537.0;
            seed = (seed * 75 + 74) % 65537;
            var r2 = seed / 65537.0;
            var b = Math.toRadians((r1 + r2 - 1) * 9.0);
            var lr = Math.toRadians(l);
            var sd = Math.sin(b) * Math.sin(dN) + Math.cos(b) * Math.cos(dN) * Math.cos(lN - lr);
            var ra = aN + Math.atan2(Math.cos(b) * Math.sin(lN - lr), Math.sin(b) * Math.cos(dN) - Math.cos(b) * Math.sin(dN) * Math.cos(lN - lr));
            mcRA.add(Math.cos(ra));
            msRA.add(Math.sin(ra));
            msDe.add(sd);
            mcDe.add(Math.sqrt(1 - sd * sd));
            mwCore.add(l > -25 && l < 25 && (r1 + r2 - 1).abs() < 0.4);
        }
        // Colinas: perfil simétrico, se calcula una sola vez.
        hillFar = [[36, 262]];
        hillNear = [[36, 262]];
        for (var x = 36; x <= 224; x += 7) {
            var dx = (x < 130) ? (130 - x) : (x - 130);
            hillFar.add([x, (241 - 7 * Math.sin(dx * 0.05) - 2 * Math.sin(dx * 0.14)).toNumber()]);
            hillNear.add([x, (248 - 3 * Math.cos(dx * 0.07)).toNumber()]);
        }
        hillFar.add([224, 262]);
        hillNear.add([224, 262]);
    }

    // ------------------------------------------------------------------
    // Estado del cielo a partir de hora, clima, fecha y ubicación.
    // ------------------------------------------------------------------
    function update(ti, d) as Void {
        var now = ti.hour * 60 + ti.min;
        var day = ti.day;
        month = ti.month;
        if (PREVIEW_MONTH > 0) { month = PREVIEW_MONTH; day = 21; }
        var tz = System.getClockTime().timeZoneOffset / 60;   // minutos respecto a UTC
        var la = d.lat;
        var lo = d.lon;
        if (PREVIEW_HM >= 0) { la = 19.43; lo = -99.13; tz = -360; }    // ubicación de prueba
        var t = null;
        if (la != null && lo != null) {
            t = sunTimes(la, lo, dayOfYear(ti.year, month, day), tz);
        } else if (d.srMin != null && d.ssMin != null) {
            t = [d.srMin, d.ssMin, d.srMin - 25, d.ssMin + 25, d.srMin - 55, d.ssMin + 55];
        } else {
            // Sin ubicación: longitud aproximada por la zona horaria.
            la = 20.0;
            t = sunTimes(la, tz / 4.0, dayOfYear(ti.year, month, day), tz);
        }
        var sr = t[0];
        var ss = t[1];
        south = (la != null && la < 0);

        // Tiempo sidéreo local: dice qué parte del cielo estrellado está
        // sobre ti (gira 15° por hora y cambia un poco cada día).
        if (lo == null) { lo = tz / 4.0; }
        lonDeg = lo;
        var phi = Math.toRadians(la);
        sinLat = Math.sin(phi);
        cosLat = Math.cos(phi);
        doyNow = dayOfYear(ti.year, month, day);
        yearNow = ti.year;
        var unix = Time.today().value() + now * 60 + (doyNow - dayOfYear(ti.year, ti.month, ti.day)) * 86400;
        tMin = unix / 60;
        var dd = (unix - 946728000).toDouble() / 86400.0d;
        var gmst = 280.46061837d + 360.98564736629d * dd;
        gmst = gmst - Math.floor(gmst / 360.0d) * 360.0d;
        lst = Math.toRadians(gmst + lo);

        // Nubes empujadas por el viento real (de dónde viene → hacia dónde va).
        windVx = 0.25;
        if (d.windBearing != null) {
            var spd = (d.windSpeed != null) ? d.windSpeed : 3.0;
            var v = 0.08 + spd * 0.06;
            if (v > 0.8) { v = 0.8; }
            // Viendo al sur: hacia el oeste es a la derecha, hacia el este a la izquierda.
            var to = Math.toRadians(d.windBearing + 180);
            windVx = -Math.sin(to) * v;
            if (windVx > -0.05 && windVx < 0.05) { windVx = (windVx < 0) ? -0.05 : 0.05; }
        }

        // Fases con los crepúsculos reales (civil −6°, náutico −12°).
        if (now < t[4] || now > t[5]) { phase = SK_NIGHT; }
        else if (now < t[2]) { phase = SK_DAWN; }
        else if (now < sr + 35) { phase = SK_SUNRISE; }
        else if (now < ss - 60) { phase = SK_DAY; }
        else if (now < ss - 8) { phase = SK_GOLDEN; }
        else if (now < t[3]) { phase = SK_SUNSET; }
        else { phase = SK_DUSK; }

        // Estación (meteorológica). En el hemisferio sur se invierte.
        var m = month;
        season = (m >= 3 && m <= 5) ? 0 : ((m >= 6 && m <= 8) ? 1 : ((m >= 9 && m <= 11) ? 2 : 3));
        if (south) { season = (season + 2) % 4; }

        wx = useWeather ? weatherCat(d.cond) : WX_CLEAR;
        if (PREVIEW_WX >= 0 && useWeather) { wx = PREVIEW_WX; }

        // Sol: de la izquierda (este) al amanecer a la derecha (oeste) al atardecer.
        sunUp = (now >= sr && now <= ss);
        sunAng = sunUp ? (-84.0 + 168.0 * (now - sr) / (ss - sr)) : 0.0;

        // Luna: su tránsito se atrasa ~50 min cada día respecto al sol.
        var secs = Time.now().value() - NEW_MOON_REF;
        moonP = secs / 86400.0 / SYNODIC;
        moonP = moonP - Math.floor(moonP);
        if (PREVIEW_MOON >= 0) { moonP = PREVIEW_MOON / 100.0; }
        var noon = (sr + ss) / 2.0;
        var transit = noon + moonP * 1440.0;
        var h = now - transit;
        while (h > 720) { h -= 1440; }
        while (h < -720) { h += 1440; }
        moonUp = (h > -MOON_HALF && h < MOON_HALF) && moonP > 0.03 && moonP < 0.97;
        moonAng = -84.0 + 168.0 * (h + MOON_HALF) / (2.0 * MOON_HALF);

        // Estrellas: solo de noche (o crepúsculo) y sin nubes cerradas.
        var dark = (phase == SK_NIGHT || phase == SK_DUSK || phase == SK_DAWN);
        // El clima es solo un detalle: el cielo estrellado siempre se ve.
        showStars = dark;
    }

    function dayOfYear(y, m, dd) {
        var cum = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
        var n = cum[m - 1] + dd;
        if (m > 2 && y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)) { n += 1; }
        return n;
    }

    // Amanecer, atardecer y crepúsculos (minutos locales) con la fórmula
    // solar de la NOAA. Devuelve [amanecer, atardecer, alba civil,
    // ocaso civil, alba náutica, ocaso náutico].
    function sunTimes(la, lo, doy, tz) {
        var g = 2 * Math.PI / 365.0 * (doy - 1);
        var eq = 229.18 * (0.000075 + 0.001868 * Math.cos(g) - 0.032077 * Math.sin(g)
                 - 0.014615 * Math.cos(2 * g) - 0.040849 * Math.sin(2 * g));
        var decl = 0.006918 - 0.399912 * Math.cos(g) + 0.070257 * Math.sin(g) - 0.006758 * Math.cos(2 * g)
                 + 0.000907 * Math.sin(2 * g) - 0.002697 * Math.cos(3 * g) + 0.00148 * Math.sin(3 * g);
        var noon = 720 - 4 * lo - eq + tz;
        var res = [];
        var zen = [90.833, 96.0, 102.0];
        for (var i = 0; i < 3; i++) {
            var phi = Math.toRadians(la);
            var c = Math.cos(Math.toRadians(zen[i])) / (Math.cos(phi) * Math.cos(decl)) - Math.tan(phi) * Math.tan(decl);
            if (c > 1) { c = 1; }
            if (c < -1) { c = -1; }
            var ha = Math.toDegrees(Math.acos(c));
            res.add(noon - 4 * ha);
            res.add(noon + 4 * ha);
        }
        return res;
    }

    function illum() {
        return (1 - Math.cos(2 * Math.PI * moonP)) / 2.0;
    }

    function weatherCat(c) {
        if (c == null) { return WX_CLEAR; }
        if (c == Weather.CONDITION_CLEAR || c == Weather.CONDITION_MOSTLY_CLEAR || c == Weather.CONDITION_FAIR) { return WX_CLEAR; }
        if (c == Weather.CONDITION_PARTLY_CLOUDY || c == Weather.CONDITION_PARTLY_CLEAR || c == Weather.CONDITION_THIN_CLOUDS) { return WX_PARTLY; }
        if (c == Weather.CONDITION_THUNDERSTORMS || c == Weather.CONDITION_SCATTERED_THUNDERSTORMS || c == Weather.CONDITION_CHANCE_OF_THUNDERSTORMS
            || c == Weather.CONDITION_TORNADO || c == Weather.CONDITION_HURRICANE || c == Weather.CONDITION_TROPICAL_STORM || c == Weather.CONDITION_SQUALL) { return WX_STORM; }
        if (c == Weather.CONDITION_SNOW || c == Weather.CONDITION_LIGHT_SNOW || c == Weather.CONDITION_HEAVY_SNOW || c == Weather.CONDITION_FLURRIES
            || c == Weather.CONDITION_CHANCE_OF_SNOW || c == Weather.CONDITION_CLOUDY_CHANCE_OF_SNOW || c == Weather.CONDITION_ICE_SNOW
            || c == Weather.CONDITION_WINTRY_MIX || c == Weather.CONDITION_RAIN_SNOW || c == Weather.CONDITION_LIGHT_RAIN_SNOW
            || c == Weather.CONDITION_HEAVY_RAIN_SNOW || c == Weather.CONDITION_SLEET || c == Weather.CONDITION_ICE || c == Weather.CONDITION_HAIL) { return WX_SNOW; }
        if (c == Weather.CONDITION_RAIN || c == Weather.CONDITION_LIGHT_RAIN || c == Weather.CONDITION_HEAVY_RAIN || c == Weather.CONDITION_DRIZZLE
            || c == Weather.CONDITION_SHOWERS || c == Weather.CONDITION_LIGHT_SHOWERS || c == Weather.CONDITION_HEAVY_SHOWERS
            || c == Weather.CONDITION_SCATTERED_SHOWERS || c == Weather.CONDITION_FREEZING_RAIN || c == Weather.CONDITION_UNKNOWN_PRECIPITATION) { return WX_RAIN; }
        if (c == Weather.CONDITION_FOG || c == Weather.CONDITION_MIST || c == Weather.CONDITION_HAZY || c == Weather.CONDITION_HAZE
            || c == Weather.CONDITION_SMOKE || c == Weather.CONDITION_DUST || c == Weather.CONDITION_SAND || c == Weather.CONDITION_SANDSTORM
            || c == Weather.CONDITION_VOLCANIC_ASH) { return WX_FOG; }
        if (c == Weather.CONDITION_CHANCE_OF_SHOWERS || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN || c == Weather.CONDITION_CHANCE_OF_RAIN_SNOW
            || c == Weather.CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW) { return WX_CLOUDY; }
        if (c == Weather.CONDITION_MOSTLY_CLOUDY || c == Weather.CONDITION_CLOUDY) { return WX_CLOUDY; }
        return WX_PARTLY;
    }

    // ------------------------------------------------------------------
    // Dibujo
    // ------------------------------------------------------------------

    // Dibuja el cielo en dc. awake/sec permiten pequeños detalles vivos
    // (estrellas que titilan, lluvia, relámpagos) con la muñeca levantada.
    function draw(dc, ti, d, awake, isDigital) as Void {
        if (isDigital != digital) { digital = isDigital; key = ""; }
        update(ti, d);
        // Se rehace cada 10 minutos (cielo que gira, nubes que avanzan) o
        // cuando cambia la fase, el clima, la luna o el sol.
        var k = phase + "," + wx + "," + season + "," + (moonUp ? (moonAng / 3).toNumber() : 99) + ","
              + (sunUp ? (sunAng / 3).toNumber() : 99) + "," + (moonP * 40).toNumber() + "," + south + ","
              + (tMin / 10) + "," + digital;
        var b = (bufRef != null) ? bufRef.get() : null;
        if (b == null && (Graphics has :createBufferedBitmap)) {
            bufRef = Graphics.createBufferedBitmap({:width => 260, :height => 260});
            b = (bufRef != null) ? bufRef.get() : null;
            key = "";
        }
        if (b != null) {
            if (!k.equals(key)) {
                render(b.getDc());
                key = k;
            }
            dc.drawBitmap(0, 0, b);
        } else {
            render(dc);
        }
        live(dc, ti.sec, awake);
    }

    function render(dc) as Void {
        if (dc has :setAntiAlias) { dc.setAntiAlias(false); }
        gradient(dc, skyStops());
        if (showStars) { stars(dc); }
        // Con nublado el sol y la luna se asoman entre las nubes.
        if (sunUp) { sun(dc); }
        if (moonUp) { moon(dc); }
        clouds(dc);
        weatherStatic(dc);
        hills(dc);
        if (dc has :setAntiAlias) { dc.setAntiAlias(true); }
    }

    // Colores del cielo de arriba hacia abajo.
    function skyStops() {
        var night = (phase == SK_NIGHT || phase == SK_DUSK || phase == SK_DAWN);
        switch (phase) {
            case SK_DAWN:    return [0x000000, 0x000055, 0x550055, (season == 0) ? 0xAA5555 : 0xAA0055];
            case SK_SUNRISE: return [0x000055, 0x550055, 0xAA0055, 0xFF5500];
            case SK_DAY:
                if (season == 3) { return [0x000055, 0x0055AA, 0x5555AA]; }
                if (season == 1) { return [0x000055, 0x0055AA, 0x0055AA]; }
                return [0x000055, 0x0055AA, 0x0055AA];
            case SK_GOLDEN:  return [0x000055, 0x0055AA, 0x5555AA, 0xAA5500];
            case SK_SUNSET:  return [0x000055, 0x550055, 0xAA0000, (season == 2) ? 0xFF5500 : 0xFF0055];
            case SK_DUSK:    return [0x000000, 0x000055, 0x000055, 0x550055];
        }
        // Noche: con luna llena el cielo se aclara un poco.
        if (moonUp && illum() > 0.6) { return [0x000000, 0x000055, 0x000055]; }
        return [0x000000, 0x000000, 0x000055];
    }

    // Degradado vertical con tramado de líneas diagonales (la pantalla
    // solo tiene 64 colores, así se simulan los tonos intermedios).
    function gradient(dc, stops) as Void {
        var n = stops.size() - 1;
        var lv = 7;
        var total = n * lv;
        for (var i = 0; i < total; i++) {
            var y0 = (260 * i / total);
            var y1 = (260 * (i + 1) / total);
            var seg = i / lv;
            var l = i % lv;
            band(dc, y0, y1 - y0, stops[seg], stops[seg + 1], l);
        }
    }

    // Franja con mezcla c0→c1. l = 0..6 → 0, 1/4, 1/3, 1/2, 2/3, 3/4, 1.
    function band(dc, y, h, c0, c1, l) as Void {
        var base = (l <= 3) ? c0 : c1;
        var over = (l <= 3) ? c1 : c0;
        var sp = [0, 4, 3, 2, 3, 4, 0][l];
        dc.setColor(base, base);
        dc.fillRectangle(0, y, 260, h);
        if (sp == 0 || c0 == c1) { return; }
        dc.setColor(over, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Diagonales alineadas globalmente: (x - y) múltiplo de sp.
        var x = -h - sp;
        x -= ((x - y) % sp + sp) % sp;
        for (; x < 260; x += sp) {
            dc.drawLine(x, y, x + h, y + h);
        }
    }

    // Posición en el arco del cielo: -90 = horizonte izquierdo, 0 = arriba.
    // Las digitales usan un arco más pegado al borde para no tapar textos.
    var digital = false;
    var useWeather = true;   // false = siempre despejado

    function skyPos(a) {
        var t = Math.toRadians(a);
        if (digital) {
            return [130 + 109 * Math.sin(t), 130 - 109 * Math.cos(t)];
        }
        return [130 + 104 * Math.sin(t), 148 - 104 * Math.cos(t)];
    }

    // Proyección del cielo visto hacia el sur: el este a la izquierda, el
    // oeste a la derecha y el cenit arriba. Devuelve [x, y] o null.
    function project(ra, dec) {
        var ha = lst - ra;
        var cd = Math.cos(dec);
        var sd = Math.sin(dec);
        var ch = Math.cos(ha);
        var up = sd * sinLat + cd * cosLat * ch;          // altura
        if (up < 0.03) { return null; }
        var north = sd * cosLat - cd * sinLat * ch;
        if (north > 0.45) { return null; }                 // a tus espaldas (norte)
        var west = cd * Math.sin(ha);
        var x = 130 + 118 * west;
        var y = 224 - 184 * up;
        var dx = x - 130;
        var dy = y - 130;
        if (dx * dx + dy * dy > 124 * 124) { return null; }
        return [x.toNumber(), y.toNumber()];
    }

    function stars(dc) as Void {
        var n = cRA.size();
        var dark = (phase == SK_NIGHT);
        // Con luna brillante se ven muchas menos estrellas.
        var moonGlare = moonUp ? illum() : 0.0;
        var limit = n;
        if (moonGlare > 0.15) { limit = (n * (1.0 - 0.65 * moonGlare)).toNumber(); }
        if (dark && moonGlare < 0.25 && wx != WX_STORM) { milkyWay(dc); }
        visX = [];
        visY = [];
        var cl = Math.cos(lst);
        var sl = Math.sin(lst);
        for (var i = 0; i < limit; i++) {
            var bright = (i % 9 == 0);
            if (!dark && !bright) { continue; }     // en el crepúsculo solo las brillantes
            // cos/sen del ángulo horario sin trigonometría por estrella
            var ch = cl * cRA[i] + sl * sRA[i];
            var up = sDe[i] * sinLat + cDe[i] * cosLat * ch;
            if (up < 0.03) { continue; }
            if (sDe[i] * cosLat - cDe[i] * sinLat * ch > 0.45) { continue; }
            var x = (130 + 118 * cDe[i] * (sl * cRA[i] - cl * sRA[i])).toNumber();
            var y = (224 - 184 * up).toNumber();
            if ((x - 130) * (x - 130) + (y - 130) * (y - 130) > 15376) { continue; }
            visX.add(x);
            visY.add(y);
            dc.setColor(bright ? 0xFFFFFF : ((i % 3 == 0) ? 0xAAAAAA : 0x555555), Graphics.COLOR_TRANSPARENT);
            dc.drawPoint(x, y);
            if (bright && dark) {
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.drawPoint(x - 1, y);
                dc.drawPoint(x + 1, y);
                dc.drawPoint(x, y - 1);
                dc.drawPoint(x, y + 1);
            }
        }
        if (dark) { constellations(dc); }
    }

    // Vía Láctea en su lugar real del cielo (se ve solo en noches sin luna).
    function milkyWay(dc) as Void {
        var n = mcRA.size();
        var cl = Math.cos(lst);
        var sl = Math.sin(lst);
        for (var i = 0; i < n; i++) {
            var ch = cl * mcRA[i] + sl * msRA[i];
            var up = msDe[i] * sinLat + mcDe[i] * cosLat * ch;
            if (up < 0.03) { continue; }
            if (msDe[i] * cosLat - mcDe[i] * sinLat * ch > 0.45) { continue; }
            var x = (130 + 118 * mcDe[i] * (sl * mcRA[i] - cl * msRA[i])).toNumber();
            var y = (224 - 184 * up).toNumber();
            if ((x - 130) * (x - 130) + (y - 130) * (y - 130) > 15376) { continue; }
            dc.setColor(mwCore[i] ? 0x5555AA : ((i % 2 == 0) ? 0x555555 : 0x000055), Graphics.COLOR_TRANSPARENT);
            dc.drawPoint(x, y);
            if (mwCore[i] || (season == 1 && i % 3 == 0)) { dc.drawPoint(x + 1, y); }
        }
    }

    // Las constelaciones que de verdad están en tu cielo ahora (máx. 2,
    // las más altas). Salen por el este y se ponen por el oeste.
    function constellations(dc) as Void {
        var best = [-1, -1];
        var bestY = [999, 999];
        var pos = [null, null];
        for (var i = 0; i < 12; i++) {
            var p = project(Math.toRadians(CONST_CENTER[i][0] * 15), Math.toRadians(CONST_CENTER[i][1]));
            if (p == null || p[1] > 175) { continue; }
            if (p[1] < bestY[0]) {
                best[1] = best[0]; bestY[1] = bestY[0]; pos[1] = pos[0];
                best[0] = i; bestY[0] = p[1]; pos[0] = p;
            } else if (p[1] < bestY[1]) {
                best[1] = i; bestY[1] = p[1]; pos[1] = p;
            }
        }
        for (var k = 0; k < 2; k++) {
            if (best[k] < 0) { continue; }
            // No encimar dos constelaciones.
            if (k == 1 && pos[0] != null && (pos[1][0] - pos[0][0]).abs() < 50 && (pos[1][1] - pos[0][1]).abs() < 44) { continue; }
            drawConstellation(dc, best[k], pos[k][0], pos[k][1]);
        }
    }

    function drawConstellation(dc, idx, cx, cy) as Void {
        var pts = CONST_PTS[idx];
        var lines = CONST_LINES[idx];
        var w = 46.0;
        var hgt = 40.0;
        var ox = cx - w / 2;
        var oy = cy - hgt / 2;
        dc.setPenWidth(1);
        dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            var a = pts[lines[i][0]];
            var b = pts[lines[i][1]];
            dc.drawLine(ox + a[0] * w / 100, oy + a[1] * hgt / 100, ox + b[0] * w / 100, oy + b[1] * hgt / 100);
        }
        for (var i = 0; i < pts.size(); i++) {
            var x = ox + pts[i][0] * w / 100;
            var y = oy + pts[i][1] * hgt / 100;
            if (pts[i][2] == 2) {
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 1);
            } else {
                dc.setColor(0xAAAAAA, Graphics.COLOR_TRANSPARENT);
                dc.drawPoint(x, y);
                dc.drawPoint(x + 1, y);
            }
        }
    }

    function sun(dc) as Void {
        var p = skyPos(sunAng);
        var x = p[0];
        var y = p[1];
        var low = (phase == SK_SUNRISE || phase == SK_SUNSET);
        var gold = (phase == SK_GOLDEN);
        var core = low ? 0xFF5500 : (gold ? 0xFFAA00 : 0xFFFF55);
        var halo = low ? 0xAA0000 : (gold ? 0xFF5500 : 0xFFAA00);
        dc.setPenWidth(1);
        // Halo de anillos punteados
        dc.setColor(halo, Graphics.COLOR_TRANSPARENT);
        for (var r = 13; r <= 21; r += 4) {
            for (var a = 0; a < 360; a += (r > 16 ? 12 : 8)) {
                var t = Math.toRadians(a + r * 3);
                dc.drawPoint(x + Math.cos(t) * r, y + Math.sin(t) * r);
            }
        }
        var sr = digital ? 7 : 9;
        dc.setColor(halo, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, sr + 2);
        dc.setColor(core, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, sr);
        if (!low) {
            dc.setColor(0xFFFFAA, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(x - 2, y - 2, 4);
        }
    }

    // Luna con su fase real. Hemisferio norte: crece por la derecha.
    function moon(dc) as Void {
        var p = skyPos(moonAng);
        var cx = p[0].toNumber();
        var cy = p[1].toNumber();
        var r = digital ? 9 : 11;
        var day = !(phase == SK_NIGHT || phase == SK_DUSK || phase == SK_DAWN);
        var lit = day ? 0xAAAAAA : 0xFFFFAA;
        var crater = day ? 0x5555AA : 0xAAAA55;
        var k = Math.cos(2 * Math.PI * moonP);
        // En el sur la luna se ve al revés (crece por la izquierda).
        var rightLit = (moonP < 0.5) != south;
        dc.setPenWidth(1);
        // Halo de luz lunar
        if (!day && illum() > 0.4) {
            dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r + 7);
            dc.setColor(0x0055AA, Graphics.COLOR_TRANSPARENT);
            for (var a = 0; a < 360; a += 10) {
                var t = Math.toRadians(a);
                dc.drawPoint(cx + Math.cos(t) * (r + 4), cy + Math.sin(t) * (r + 4));
            }
        }
        // Parte oscura (luz cenicienta)
        if (!day) {
            dc.setColor(0x000055, Graphics.COLOR_TRANSPARENT);
            dc.fillCircle(cx, cy, r);
            dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
        }
        // Parte iluminada, fila por fila.
        dc.setColor(lit, Graphics.COLOR_TRANSPARENT);
        var xl = [];
        var xr = [];
        for (var dy = -r; dy <= r; dy++) {
            var w = Math.sqrt(r * r - dy * dy);
            var a;
            var b;
            if (moonP < 0.5) { a = w * k; b = w; } else { a = -w; b = -w * k; }
            if (!rightLit && moonP < 0.5 || rightLit && moonP >= 0.5) {
                var t = a;
                a = -b;
                b = -t;
            }
            xl.add(a);
            xr.add(b);
            if (b - a >= 0.5) {
                dc.drawLine(cx + a.toNumber(), cy + dy, cx + b.toNumber() + 1, cy + dy);
            }
        }
        // Cráteres (mares), solo donde hay luz.
        var cr = [[-4, -3, 3], [3, 2, 2], [-1, 5, 2], [5, -5, 1], [-6, 3, 1]];
        dc.setColor(crater, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < cr.size(); i++) {
            var row = cr[i][1] + r;
            if (cr[i][0] > xl[row] + 1 && cr[i][0] < xr[row] - 1) {
                dc.fillCircle(cx + cr[i][0], cy + cr[i][1], cr[i][2] - 1);
                if (cr[i][2] > 1) { dc.drawPoint(cx + cr[i][0], cy + cr[i][1]); }
            }
        }
    }

    // Nube hecha de círculos, con borde iluminado arriba.
    function cloud(dc, x, y, s, body, edge) as Void {
        dc.setColor(edge, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s, y, s * 0.7 + 1);
        dc.fillCircle(x, y - s * 0.5, s + 1);
        dc.fillCircle(x + s * 1.1, y - s * 0.1, s * 0.8 + 1);
        dc.setColor(body, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x - s, y + 1, s * 0.7);
        dc.fillCircle(x, y - s * 0.5 + 1, s);
        dc.fillCircle(x + s * 1.1, y, s * 0.8);
        dc.fillRectangle(x - s * 1.6, y + 1, s * 3.4, s * 0.6);
    }

    function clouds(dc) as Void {
        if (wx == WX_CLEAR) { return; }
        var night = (phase == SK_NIGHT || phase == SK_DUSK || phase == SK_DAWN);
        var body;
        var edge;
        // Nubes con los tonos del cielo (nada de gris).
        var lowSun = (phase == SK_SUNSET || phase == SK_SUNRISE);
        if (wx == WX_STORM) {
            body = 0x000055; edge = night ? 0x555555 : 0x5555AA;
        } else if (night) {
            body = 0x000055; edge = (moonUp && illum() > 0.4) ? 0xAAAAAA : 0x5555AA;
        } else if (lowSun) {
            body = 0x550055; edge = 0xFFAA55;
        } else if (phase == SK_GOLDEN) {
            body = 0x5555AA; edge = 0xFFAA55;
        } else {
            body = 0x5555AA; edge = 0xAAAAFF;
        }
        // Acomodo distinto cada día; avanzan con el viento a lo largo del día.
        // Clima mínimo: pocas nubes pequeñas arriba, sin tapar el cielo.
        var n = (wx == WX_PARTLY) ? 2 : 3;
        cloudX = [];
        cloudY = [];
        var seed = (yearNow * 367 + doyNow) % 65537;
        var span = 330.0;
        for (var i = 0; i < n; i++) {
            seed = (seed * 75 + 74) % 65537;
            var x0 = (seed % 330) + i * 47;
            seed = (seed * 75 + 74) % 65537;
            var y = 26 + seed % 40;
            seed = (seed * 75 + 74) % 65537;
            var sz = 5 + seed % 4;
            // Las de arriba van un poco más rápido (efecto de profundidad).
            var x = x0 + windVx * (1.2 - y / 250.0) * (tMin % 100000);
            x = x - Math.floor(x / span) * span - 35;
            cloud(dc, x, y, sz, body, edge);
            cloudX.add(x.toNumber());
            cloudY.add(y + sz);
        }
    }

    // Detalles fijos del clima: niebla en franjas.
    function weatherStatic(dc) as Void {
        if (wx != WX_FOG) { return; }
        var night = (phase == SK_NIGHT || phase == SK_DUSK || phase == SK_DAWN);
        dc.setColor(night ? 0x000055 : 0x5555AA, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Unas pocas franjas sobre el horizonte.
        for (var y = 214; y < 236; y += 7) {
            var off = (y * 7) % 23;
            for (var x = 40 - off; x < 220; x += 46) {
                dc.drawLine(x, y, x + 26, y);
            }
        }
    }

    // Colinas en el horizonte con el color de la estación.
    function hills(dc) as Void {
        var night = (phase == SK_NIGHT || phase == SK_DUSK || phase == SK_DAWN);
        var far;
        var near;
        if (night) {
            far = 0x000055; near = 0x000000;
            if (season == 3 || wx == WX_SNOW) { far = 0x555555; near = 0x000055; }
        } else if (wx == WX_SNOW || season == 3) {
            far = 0xAAAAAA; near = 0x555555;
        } else if (season == 2) {
            far = 0xAA5500; near = 0x550000;
        } else if (season == 1) {
            far = 0x00AA00; near = 0x005500;
        } else {
            far = 0x55AA55; near = 0x005500;
        }
        dc.setColor(far, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(hillFar);
        dc.setColor(near, Graphics.COLOR_TRANSPARENT);
        dc.fillPolygon(hillNear);
    }

    // Detalles vivos con la muñeca levantada (se actualizan cada segundo).
    function live(dc, sec, awake) as Void {
        dc.setPenWidth(1);
        if (!awake) { sec = 0; }
        if (showStars && awake) {
            // Algunas estrellas titilan.
            var n = visX.size();
            for (var i = 0; i < 6 && n > 0; i++) {
                var j = (sec * 17 + i * 31) % n;
                dc.setColor((i % 2 == 0) ? 0xFFFFFF : 0x000055, Graphics.COLOR_TRANSPARENT);
                dc.drawPoint(visX[j], visY[j]);
            }
            // Estrella fugaz de vez en cuando en noches oscuras.
            if (phase == SK_NIGHT && sec % 20 == 13) {
                var sx = 60 + (sec * 37) % 120;
                var sy = 30 + (sec * 13) % 50;
                dc.setColor(0x555555, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(sx - 22, sy - 9, sx - 10, sy - 4);
                dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(sx - 10, sy - 4, sx, sy);
            }
        }
        // Lluvia y nieve solo debajo de las nubecitas.
        var nc = cloudX.size();
        if (nc > 0 && (wx == WX_RAIN || wx == WX_STORM)) {
            dc.setColor(0x55AAFF, Graphics.COLOR_TRANSPARENT);
            var shift = (sec * 5) % 12;
            for (var c = 0; c < nc; c++) {
                for (var i = 0; i < 4; i++) {
                    var x = cloudX[c] - 8 + i * 5;
                    var y = cloudY[c] + 3 + ((i * 7 + shift) % 12);
                    dc.drawLine(x, y, x - 1, y + 3);
                }
            }
            if (awake && wx == WX_STORM && sec % 6 == 2) {
                var bx = cloudX[sec % nc];
                var by = cloudY[sec % nc];
                dc.setColor(0xFFFF55, Graphics.COLOR_TRANSPARENT);
                dc.drawLine(bx, by, bx - 4, by + 9);
                dc.drawLine(bx - 4, by + 9, bx + 1, by + 10);
                dc.drawLine(bx + 1, by + 10, bx - 4, by + 20);
            }
        } else if (nc > 0 && wx == WX_SNOW) {
            dc.setColor(0xFFFFFF, Graphics.COLOR_TRANSPARENT);
            var shift = (sec * 3) % 14;
            for (var c = 0; c < nc; c++) {
                for (var i = 0; i < 4; i++) {
                    var x = cloudX[c] - 8 + i * 5 + ((i + sec) % 2);
                    var y = cloudY[c] + 3 + ((i * 5 + shift) % 14);
                    dc.drawPoint(x, y);
                }
            }
        }
    }

}
