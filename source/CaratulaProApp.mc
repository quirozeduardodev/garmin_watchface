import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class CaratulaProApp extends Application.AppBase {
    var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        mView = new CaratulaProView();
        return [mView, new CaratulaProDelegate(mView)];
    }

    // Menú "Personalizar" que aparece al elegir la carátula en el reloj.
    function getSettingsView() {
        return [new CPSettingsMenu(), new CPSettingsDelegate()];
    }

    function onSettingsChanged() as Void {
        if (mView != null) {
            mView.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}

// Si el reloj avisa que el segundero "siempre" gasta demasiado,
// la carátula vuelve a mostrarlo solo al levantar la muñeca.
class CaratulaProDelegate extends WatchUi.WatchFaceDelegate {
    var mView;

    function initialize(view) {
        WatchFaceDelegate.initialize();
        mView = view;
    }

    function onPowerBudgetExceeded(info) {
        mView.budgetExceeded = true;
        WatchUi.requestUpdate();
    }
}
