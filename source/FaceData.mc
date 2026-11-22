import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.ActivityMonitor;
import Toybox.Activity;
import Toybox.SensorHistory;
import Toybox.Weather;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Complications;

// Reúne todos los datos que muestran las carátulas.
// Los valores pueden ser null cuando el reloj no los tiene disponibles.
class FaceData {
    var hr = null;
    var bb = null;
    var stress = null;
    var spo2 = null;
    var steps = 0;
    var stepGoal = 10000;
    var kcal = 0;
    var floors = 0;
    var imin = 0;
    var imGoal = 150;
    var runDist = null;      // metros corridos en la semana
    var temp = null;         // grados Celsius
    var bat = 0;
    var notif = 0;
    var phone = false;
    var cond = null;
    var sunrise = null;
    var sunset = null;
    var srMin = null;        // amanecer, minutos desde medianoche
    var ssMin = null;        // atardecer, minutos desde medianoche
    var lat = null;          // ubicación (grados) para calcular el sol
    var lon = null;
    var windSpeed = null;    // m/s
    var windBearing = null;  // grados, de dónde viene el viento

    function initialize() {
    }

    // Datos ligeros: se leen en cada actualización.
    function refreshFast() as Void {
        bat = System.getSystemStats().battery.toNumber();
        var ds = System.getDeviceSettings();
        notif = ds.notificationCount;
        phone = ds.phoneConnected;

        hr = null;
        var ai = Activity.getActivityInfo();
        if (ai != null && ai.currentHeartRate != null) {
            hr = ai.currentHeartRate;
        } else {
            var it = ActivityMonitor.getHeartRateHistory(1, true);
            if (it != null) {
                var s = it.next();
                if (s != null && s.heartRate != null && s.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                    hr = s.heartRate;
                }
            }
        }
    }

    // Datos más pesados: se leen una vez por minuto.
    function refreshSlow() as Void {
        var am = ActivityMonitor.getInfo();
        steps = nz(am.steps, 0);
        stepGoal = nz(am.stepGoal, 10000);
        if (stepGoal <= 0) { stepGoal = 10000; }
        kcal = nz(am.calories, 0);
        floors = nz(am.floorsClimbed, 0);
        if (am.activeMinutesWeek != null) {
            imin = nz(am.activeMinutesWeek.total, 0);
        }
        imGoal = nz(am.activeMinutesWeekGoal, 150);
        if (imGoal <= 0) { imGoal = 150; }

        if (Toybox has :SensorHistory) {
            if (SensorHistory has :getBodyBatteryHistory) {
                bb = lastSample(SensorHistory.getBodyBatteryHistory({:period => 1}));
            }
            if (SensorHistory has :getStressHistory) {
                stress = lastSample(SensorHistory.getStressHistory({:period => 1}));
            }
            if (SensorHistory has :getOxygenSaturationHistory) {
                spo2 = lastSample(SensorHistory.getOxygenSaturationHistory({:period => 1}));
            }
        }

        runDist = null;
        if (Toybox has :Complications) {
            try {
                var c = Complications.getComplication(new Complications.Id(Complications.COMPLICATION_TYPE_WEEKLY_RUN_DISTANCE));
                if (c != null && c.value != null) {
                    runDist = c.value.toFloat();
                }
            } catch (e) {
                runDist = null;
            }
        }

        temp = null;
        cond = null;
        sunrise = null;
        sunset = null;
        if (Toybox has :Weather) {
            var cc = Weather.getCurrentConditions();
            if (cc != null) {
                if (cc.temperature != null) {
                    temp = cc.temperature.toFloat();
                }
                cond = cc.condition;
                windSpeed = (cc.windSpeed != null) ? cc.windSpeed.toFloat() : null;
                windBearing = cc.windBearing;
                var loc = cc.observationLocationPosition;
                if (loc != null) {
                    var now = Time.now();
                    var sr = Weather.getSunrise(loc, now);
                    var ss = Weather.getSunset(loc, now);
                    sunrise = hhmm(sr);
                    sunset = hhmm(ss);
                    srMin = minOfDay(sr);
                    ssMin = minOfDay(ss);
                    var dg = loc.toDegrees();
                    lat = dg[0];
                    lon = dg[1];
                }
            }
        }
        resolveLocation();
    }

    // Ubicación: clima del celular, si no la última posición GPS, si no la
    // última que se guardó. Se guarda para usarla sin conexión.
    function resolveLocation() as Void {
        var found = (lat != null && lon != null);
        if (!found) {
            var ai = Activity.getActivityInfo();
            if (ai != null && ai.currentLocation != null) {
                var dg = ai.currentLocation.toDegrees();
                if (dg[0] != 0 || dg[1] != 0) {
                    lat = dg[0];
                    lon = dg[1];
                    found = true;
                }
            }
        }
        var st = Application.Storage.getValue("loc");
        if (found) {
            if (st == null || (st[0] - lat).abs() > 0.05 || (st[1] - lon).abs() > 0.05) {
                Application.Storage.setValue("loc", [lat, lon]);
            }
        } else if (st != null) {
            lat = st[0];
            lon = st[1];
        }
    }

    function nz(v, d) {
        return (v == null) ? d : v;
    }

    function lastSample(it) {
        if (it == null) { return null; }
        var s = it.next();
        if (s == null || s.data == null) { return null; }
        return s.data.toNumber();
    }

    function minOfDay(moment) {
        if (moment == null) { return null; }
        var i = Gregorian.info(moment, Time.FORMAT_SHORT);
        return i.hour * 60 + i.min;
    }

    function hhmm(moment) {
        if (moment == null) { return null; }
        var i = Gregorian.info(moment, Time.FORMAT_SHORT);
        return i.hour.format("%02d") + ":" + i.min.format("%02d");
    }
}
