import QtQuick 1.1
import com.victron.velib 1.0
import "utils.js" as Utils

// changes to handle SeeLevel NMEA2000 tank sensor:
// Ignore over the real SeeLevel dBus service because it's information changes

// Search for //////// SeeLevel to find sections to modify

// Also, see changes in TileText.qml

// When a tank is empty or nearly so, the red bar graph can't be seen, so the tank fullness text now turns red also


OverviewPage {
	id: root

	property variant sys: theSystem
	property string settingsBindPreffix: "com.victronenergy.settings"
	property string pumpBindPreffix: "com.victronenergy.pump.startstop0"
	property variant activeNotifications: NotificationCenter.notifications.filter(
											  function isActive(obj) { return obj.active} )
	property string noAdjustableByDmc: qsTr("This setting is disabled when a Digital Multi Control " +
											"is connected. If it was recently disconnected execute " +
											"\"Redetect system\" that is avalible on the inverter menu page.")
	property string noAdjustableByBms: qsTr("This setting is disabled when a VE.Bus BMS " +
											"is connected. If it was recently disconnected execute " +
											"\"Redetect system\" that is avalible on the inverter menu page.")
	property string noAdjustableTextByConfig: qsTr("This setting is disabled. " +
										   "Possible reasons are \"Overruled by remote\" is not enabled or " +
										   "an assistant is preventing the adjustment. Please, check " +
										   "the inverter configuration with VEConfigure.")
	property int numberOfMultis: 0
	property string vebusPrefix: ""

	// Keeps track of which button on the bottom row is active
	property int buttonIndex: 0

	title: qsTr("Mobile")

	Component.onCompleted: discoverTanks()

	ListView {
		id: pwColumn

		property int tilesCount: solarTile.visible || dcSystem.visible ? 3 : 2
		property int tileHeight: Math.ceil(height / tilesCount)
		interactive: false // static tiles

		width: 136
		anchors {
			left: parent.left
			top: parent.top;
			bottom: acModeButton.top;
		}

		model: VisualItemModel {
			Tile {
				width: pwColumn.width
				height: visible ? pwColumn.tileHeight : 0
				title: qsTr("AC INPUT")
				color: "#82acde"
				visible: !dcSystem.visible || !solarTile.visible
				values: [
					TileText {
						text: sys.acInput.power.uiText
						font.pixelSize: 30
					}

				]
			}

			TileAcPower {
				width: pwColumn.width
				height: visible ? pwColumn.tileHeight : 0
				title: qsTr("AC LOADS")
				color: "#e68e8a"
				values: [
					TileText {
						text: sys.acLoad.power.uiText
						font.pixelSize: 30
					}
				]
			}

			Tile {
				id: solarTile
				width: pwColumn.width
				height: visible ? pwColumn.tileHeight : 0
				title: qsTr("PV CHARGER")
				color: "#2cc36b"
				visible  : sys.pvCharger.power.valid

				values: [
					TileText {
						font.pixelSize: 30
						text: sys.pvCharger.power.uiText
					}
				]
			}
			Tile {
				id: dcSystem
				width: pwColumn.width
				height: visible ? pwColumn.tileHeight : 0
				title: qsTr("DC SYSTEM")
				color: "#16a085"
				visible  : hasDcSys.value === 1

				VBusItem {
					id: hasDcSys
					bind: Utils.path(settingsBindPreffix, "/Settings/SystemSetup/HasDcSystem")
				}

				values: [
					TileText {
						font.pixelSize: 30
						text: sys.dcSystem.power.format(0)
					},
					TileText {
						text: !sys.dcSystem.power.valid ? "---" :
							  sys.dcSystem.power.value < 0 ? qsTr("to battery") : qsTr("from battery")
					}
				]
			}
		}
	}

	Tile {
		id: logoTile

		color: "#575748"
		height: 120
		anchors {
			left: pwColumn.right
			right: tanksColum.left
			top: parent.top
		}

		MbIcon {
			x: 1
			y: 1
			// see below, so the svg instead of a png if there is a 1x1 image
			visible: customImage.sourceSize.width === 1 && customImage.sourceSize.height === 1
			iconId: "mobile-builder-logo-svg"
		}

		// The uploaded png, the default is a 1x1 transparent pixel now.
		Image {
			id: customImage
			source: "image://theme/mobile-builder-logo"
			anchors.centerIn: parent
		}
	}

	Tile {
		id: batteryTile
		height: 112
		title: qsTr("BATTERY")
		anchors {
			left: pwColumn.right
			right: stateTile.left
			top: logoTile.bottom
			bottom: acModeButton.top
		}

		values: [
			TileText {
				text: sys.battery.soc.absFormat(0)
				font.pixelSize: 30
				height: 32
			},
			TileText {
				text: {
					if (!sys.battery.state.valid)
						return "---"
					switch(sys.battery.state.value) {
						case sys.batteryStateIdle: return qsTr("idle")
						case sys.batteryStateCharging : return qsTr("charging")
						case sys.batteryStateDischarging : return qsTr("discharging")
					}
				}
			},
			TileText {
				text: sys.battery.power.absFormat(0)
			},
			TileText {
				text: sys.battery.voltage.format(1) + "   " + sys.battery.current.format(1)
			}
		]
	}

	Tile {
		id: stateTile

		width: 104
		title: qsTr("STATUS")
		color: "#4789d0"

		anchors {
			right: tanksColum.left
			top: logoTile.bottom
			bottom: acModeButton.top
		}

		Timer {
			id: wallClock

			running: true
			repeat: true
			interval: 1000
			triggeredOnStart: true
			onTriggered: time = Qt.formatDateTime(new Date(), "hh:mm")

			property string time
		}

		values: [
			TileText {
				id: systemTile
				text: wallClock.time
				font.pixelSize: 30
			},
			TileText {
				property VeQuickItem gpsService: VeQuickItem { uid: "dbus/com.victronenergy.system/GpsService" }
				property VeQuickItem speed: VeQuickItem { uid: Utils.path("dbus/", gpsService.value, "/Speed") }
				property VeQuickItem speedUnit: VeQuickItem { uid: "dbus/com.victronenergy.settings/Settings/Gps/SpeedUnit" }

				text: speed.value === undefined ? "" : getValue()
				visible: speed.value !== undefined && speedUnit.value !== undefined

				function getValue()
				{
					if (speedUnit.value === "km/h")
						return (speed.value * 3.6).toFixed(1) + speedUnit.value
					if (speedUnit.value === "mph")
						return (speed.value * 2.236936).toFixed(1) + speedUnit.value
					if (speedUnit.value === "kt")
						return (speed.value * (3600/1852)).toFixed(1) + speedUnit.value
					return speed.value.toFixed(2) + "m/s"
				}
			},
			Marquee {
				text: notificationText()
				width: stateTile.width
				interval: 100
				fontSize: 13
			}
		]
	}

	ListView {
		id: tanksColum

		property int tileHeight: Math.ceil(height / Math.max(count, 2))
		width: 134
		interactive: false // static tiles

		model: tanksModel
		delegate: TileTank {
			width: tanksColum.width
			height: tanksColum.tileHeight
			pumpBindPrefix: root.pumpBindPreffix
		}

		anchors {
			top: root.top
			bottom: acModeButton.top
			right: root.right
		}

		Tile {
			title: qsTr("TANKS")
			anchors.fill: parent
			values: TileText {
				text: qsTr("No tanks found")
				width: parent.width
				wrapMode: Text.WordWrap
			}
			z: -1
		}
	}

	ListModel {
		id: tanksModel
	}

	Keys.forwardTo: [keyHandler]

	Item {
		id: keyHandler
		Keys.onLeftPressed: {
			if (buttonIndex > 0)
				buttonIndex--

			event.accepted = true
		}

		Keys.onRightPressed: {
			if (buttonIndex < 2)
				buttonIndex++

			event.accepted = true
		}
	}

	MouseArea {
		anchors.fill: parent
		enabled: parent.active
		onPressed: mouse.accepted = acCurrentButton.expanded
		onClicked: acCurrentButton.cancel()
	}

	TileSpinBox {
		id: acCurrentButton

		anchors.bottom: parent.bottom
		anchors.left: parent.left
		isCurrentItem: (buttonIndex == 0)
		focus: root.active && isCurrentItem

		bind: Utils.path(vebusPrefix, "/Ac/ActiveIn/CurrentLimit")
		title: qsTr("AC CURRENT LIMIT")
		color: containsMouse && !editMode ? "#d3d3d3" : "#A8A8A8"
		width: show ? 160 : 0
		fontPixelSize: 14
		unit: "A"
		readOnly: currentLimitIsAdjustable.value !== 1 || numberOfMultis > 1
		buttonColor: "#979797"

		VBusItem { id: currentLimitIsAdjustable; bind: Utils.path(vebusPrefix, "/Ac/ActiveIn/CurrentLimitIsAdjustable") }

		Keys.onSpacePressed: showErrorToast(event)

		function editIsAllowed() {
			if (numberOfMultis > 1) {
				toast.createToast(qsTr("It is not possible to change this setting when there are more than one inverter connected."), 5000)
				return false
			}

			if (currentLimitIsAdjustable.value === 0) {
				if (dmc.valid) {
					toast.createToast(noAdjustableByDmc, 5000)
					return false
				}
				if (bms.valid) {
					toast.createToast(noAdjustableByBms, 5000)
					return false
				}
				if (!dmc.valid && !bms.valid) {
					toast.createToast(noAdjustableTextByConfig, 5000)
					return false
				}
			}

			return true
		}

		function showErrorToast(event) {
			editIsAllowed()
			event.accepted = true
		}
	}

	Tile {
		id: acModeButton
		anchors.left: acCurrentButton.right
		anchors.bottom: parent.bottom
		property variant texts: { 4: qsTr("OFF"), 3: qsTr("ON"), 1: qsTr("CHARGER ONLY") }
		property int value: mode.valid ? mode.value : 3
		property bool reset: false
		isCurrentItem: (buttonIndex == 1)
		focus: root.active && isCurrentItem

		editable: true
		readOnly: !modeIsAdjustable.valid || modeIsAdjustable.value !== 1 || numberOfMultis > 1
		width: 160
		height: 45
		color: acModeButtonMouseArea.containsPressed ? "#d3d3d3" : "#A8A8A8"
		title: qsTr("AC MODE")

		values: [
			TileText {
				text: modeIsAdjustable.valid && numberOfMultis === 1 ? qsTr("%1").arg(acModeButton.texts[acModeButton.value]) : qsTr("NOT AVAILABLE")
			}
		]

		VBusItem { id: mode; bind: Utils.path(vebusPrefix, "/Mode") }
		VBusItem { id: modeIsAdjustable; bind: Utils.path(vebusPrefix,"/ModeIsAdjustable") }

		Keys.onSpacePressed: edit()

		function edit() {
			if (!mode.valid)
				return

			if (numberOfMultis > 1) {
				toast.createToast(qsTr("It is not possible to change this setting when there are more than one inverter connected."), 5000)
				return
			}


			if (modeIsAdjustable.value === 0) {
				if (dmc.valid)
					toast.createToast(noAdjustableByDmc, 5000)
				if (bms.valid)
					toast.createToast(noAdjustableByBms, 5000)
				if (!dmc.valid && !bms.valid)
					toast.createToast(noAdjustableTextByConfig, 5000)
				return
			}

			reset = true
			applyAnimation2.restart()
			reset = false
			switch(value) {
			case 4:
				value--
				break;
			case 3:
				value = 1
				break;
			case 1:
				value = 4
				break;
			}
		}

		MouseArea {
			id: acModeButtonMouseArea
			anchors.fill: parent
			property bool containsPressed: containsMouse && pressed
			onClicked:  {
				buttonIndex = 1
				parent.edit()
			}
		}

		Rectangle {
			id: timerRect2
			height: 2
			width: acModeButton.width * 0.8
			visible: applyAnimation2.running
			anchors {
				bottom: parent.bottom; bottomMargin: 5
				horizontalCenter: parent.horizontalCenter
			}
		}

		SequentialAnimation {
			id: applyAnimation2
			NumberAnimation {
				target: timerRect2
				property: "width"
				from: 0
				to: acModeButton.width * 0.8
				duration: 3000
			}

			ColorAnimation {
				target: acModeButton
				property: "color"
				from: "#A8A8A8"
				to: "#4789d0"
				duration: 200
			}

			ColorAnimation {
				target: acModeButton
				property: "color"
				from: "#4789d0"
				to: "#A8A8A8"
				duration: 200
			}
			PropertyAction {
				target: timerRect2
				property: "width"
				value: 0
			}
			onCompleted: if (!acModeButton.reset) mode.setValue(acModeButton.value)
		}
	}

	Tile {
		id: pumpButton

		anchors.left: acModeButton.right
		anchors.bottom: parent.bottom

		property variant texts: [ qsTr("AUTO"), qsTr("ON"), qsTr("OFF")]
		property int value: 0
		property bool reset: false
		property bool pumpEnabled: pumpRelay.value === 3
		isCurrentItem: (buttonIndex == 2)
		focus: root.active && isCurrentItem

		title: qsTr("PUMP")
		width: show ? 160 : 0
		height: 45
		editable: true
		readOnly: false
		color: pumpButtonMouseArea.containsPressed ? "#d3d3d3" : "#A8A8A8"

		VBusItem { id: pump; bind: Utils.path(settingsBindPreffix, "/Settings/Pump0/Mode") }
		VBusItem { id: pumpRelay; bind: Utils.path(settingsBindPreffix, "/Settings/Relay/Function") }

		values: [
			TileText {
				text: pumpButton.pumpEnabled ? qsTr("%1").arg(pumpButton.texts[pumpButton.value]) : qsTr("DISABLED")
			}
		]

		Keys.onSpacePressed: edit()

		function edit() {
			if (!pumpEnabled) {
				toast.createToast(qsTr("Pump functionality is not enabled. To enable it go to the relay settings page and set function to \"Tank pump\""), 5000)
				return
			}

			reset = true
			applyAnimation.restart()
			reset = false

			if (value < 2)
				value++
			else
				value = 0
		}

		MouseArea {
			id: pumpButtonMouseArea
			property bool containsPressed: containsMouse && pressed
			anchors.fill: parent
			onClicked: {
				buttonIndex = 2
				parent.edit()
			}
		}

		Rectangle {
			id: timerRect
			height: 2
			width: pumpButton.width * 0.8
			visible: applyAnimation.running
			anchors {
				bottom: parent.bottom; bottomMargin: 5
				horizontalCenter: parent.horizontalCenter
			}
		}

		SequentialAnimation {
			id: applyAnimation
			alwaysRunToEnd: false
			NumberAnimation {
				target: timerRect
				property: "width"
				from: 0
				to: pumpButton.width * 0.8
				duration: 3000
			}

			ColorAnimation {
				target: pumpButton
				property: "color"
				from: "#A8A8A8"
				to: "#4789d0"
				duration: 200
			}

			ColorAnimation {
				target: pumpButton
				property: "color"
				from: "#4789d0"
				to: "#A8A8A8"
				duration: 200
			}
			PropertyAction {
				target: timerRect
				property: "width"
				value: 0
			}
			// Do not set value if the animation is restarted by user pressing the button
			// to move between options
			onCompleted: if (!pumpButton.reset) pump.setValue(pumpButton.value)
		}
	}

	// When new service is found check if is a tank sensor
	Connections {
		target: DBusServices
		onDbusServiceFound: addService(service)
	}

	function addService(service)
	{
		var name = service.name
		if (service.type === DBusService.DBUS_SERVICE_TANK) {
//////// SeeLevel - add this
            var seeLevelServiceName = seeLevelName.valid ? seeLevelName.value : ""
            if (service.name !== seeLevelServiceName) // hide N2K SeeLevel dBus object
//////// SeeLevel - end add this
                tanksModel.append({serviceName: service.name})
		}
		if (service.type === DBusService.DBUS_SERVICE_MULTI) {
			numberOfMultis++
			if (vebusPrefix === "")
				vebusPrefix = name;
		}
	}

	// Check available services to find tank sesnsors
	function discoverTanks()
	{
		tanksModel.clear()
		for (var i = 0; i < DBusServices.count; i++) {
			if (DBusServices.at(i).type === DBusService.DBUS_SERVICE_TANK) {
				addService(DBusServices.at(i))
			}
			if (DBusServices.at(i).type === DBusService.DBUS_SERVICE_MULTI) {
				addService(DBusServices.at(i))
			}
		}
	}

	function notificationText()
	{
		if (activeNotifications.length === 0)
			return qsTr("no alarms")

		var descr = []
		for (var n = 0; n < activeNotifications.length; n++) {
			var notification = activeNotifications[n];

			var text = notification.serviceName + " - " + notification.description;
			if (notification.value !== "" )
				text += ":  " + notification.value

			descr.push(text)
		}

		return descr.join("  |  ")
	}

	VBusItem { id: dmc; bind: Utils.path(vebusPrefix, "/Devices/Dmc/Version") }
	VBusItem { id: bms; bind: Utils.path(vebusPrefix, "/Devices/Bms/Version") }
    //////// SeeLevel - add this
        VBusItem { id: seeLevelName;
            bind: Utils.path(settingsBindPreffix, "/Settings/Devices/TankRepeater/SeeLevelService") }
    //////// SeeLevel - end add this
}
