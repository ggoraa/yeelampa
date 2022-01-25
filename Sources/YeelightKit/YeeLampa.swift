import Foundation
import Alamofire

/// Main class of YeelightKit.
public class YeelightKit {
	public static let clientId = 2882303761517308695
	public static let clientSecret = "OrwZHJ/drEXakH1LsfwwqQ=="
	private var region: Region
	private var accessToken: String
	private let deviceListUrl: URL
	
	/// Creates a YeelightKit instance with provided credentials.
	/// - Parameters:
	/// 	- accessToken: The token you acquired when logging in.
	/// 	- region: The region we will connect to.
	public init(accessToken: String, region: Region) {
		self.region = region
		self.accessToken = accessToken
		self.deviceListUrl = URL(string: "https://\(region.rawValue).openapp.io.mi.com/openapp/user/device_list")!
	}
	
	private struct AuthResponse: Codable {
		let access_token: String
	}
	
	/// Converts an authorization grant to a usable access token.
	/// - Parameters:
	/// 	- grant: A grant to convert.
	public static func convertAuthGrantToToken(_ grant: String) async throws -> String {
		let url = URL(string: "https://account.xiaomi.com/oauth2/token")!
		let task = AF.request(
			url,
			method: .get,
			parameters: [
				"client_id": YeelightKit.clientId,
				"client_secret": YeelightKit.clientSecret,
				"grant_type": "authorization_code",
				"redirect_uri": "http://www.mi.com",
				"code": grant
			],
			headers: [
				"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4495.0 Safari/537.36"
			]
		).serializingString()
		do {
			let response = try await task.value
			let validJson = response.replacingOccurrences(of: "&&&START&&&", with: "")
			return try! JSONDecoder().decode(AuthResponse.self, from: Data(validJson.utf8)).access_token
		} catch {
			throw LoginError.unknownError
		}
	}
	
	/// Returns the device list.
	/// This function does not use a cache, it returns new data from the server.
	public func getDeviceList() async throws -> [Device] {
		var request = URLRequest(url: self.deviceListUrl)
		request.httpMethod = "POST"
		request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
		request.httpBody = Data("clientId=\(YeelightKit.clientId)&accessToken=\(self.accessToken)".utf8)
		
		let task = AF.request(self.deviceListUrl, method: .post, parameters: [
			"clientId": YeelightKit.clientId,
			"accessToken": self.accessToken
		], headers: [
			"Content-Type": "application/x-www-form-urlencoded"
		]).serializingDecodable(BaseJsonModel<DeviceListJsonModel>.self)
		return try await task.value.result.list.map { device in
			return device.toPDevice()
		}
	}
	
	/// Set a color temperature for a device that supports it. Only accepted when a device is in `on` state.
	/// - Parameters:
	///   - temp: A target temperature.
	///   - effect: An effect that wiil be used.
	///   - duration: Time that it will take.
	///   - device: A target device.
	public func setColorTemperature(to temp: Int,  withEffect effect: ChangeEffect = .smooth, withDuration duration: Int = 500, for device: Device) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_ct_abx", params: [temp, effect.rawValue, duration])
	}
	
	/// Sets an RGB color. Only accepted when a device is in `on` state.
	/// - Parameters:
	///   - color: A RGB color you want to set.
	///   - effect: An effect that wiil be used.
	///   - duration: Time that it will take.
	///   - device: A target device.
	public func setRgbColor(
		of color: (
			red: Int,
			green: Int,
			blue: Int
		),
		withEffect effect: ChangeEffect = .smooth,
		withDuration duration: Int = 500,
		for device: Device
	) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_rgb", params: [
			((color.red << 16) + (color.green << 8) + color.blue),
			effect.rawValue,
			duration]
		)
	}
	
	/// Sets an HSV color. Only accepted when a device is in `on` state.
	/// - Parameters:
	///   - color: A color you want to set. `hue`'s bounds are 0 to 359(yea, it's strange, but this is how the API works),  `saturation` is from 0 to 100, and `brightness` is from 0 to 100. Note that if a `brightness` value is provided, then there will be 2 requests, one to set the `hue` and `saturation`, and one for `brightness`. Don't blame me on this design, this is how the API works! :D
	///   - effect: An effect that wiil be used.
	///   - duration: Time that it will take.
	///   - device: A target device.
	public func setHsvColor(
		of color: (
			hue: Int,
			saturation: Int
		),
		withEffect effect: ChangeEffect = .smooth,
		withDuration duration: Int = 500,
		for device: Device
	) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_hsv", params: [color.hue, color.saturation, effect.rawValue, duration])
	}
	
	/// Sets the brightness of a device. Only accepted when a device is in `on` state.
	/// - Parameters:
	///   - value: A brightness value you want to set. Allowed values are from 0 to 100.
	///   - effect: An effect that wiil be used.
	///   - duration: Time that it will take.
	///   - device: A target device.
	public func setBrightness(to value: Int, withEffect effect: ChangeEffect = .smooth, withDuration duration: Int = 500, for device: Device) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_bright", params: [value, effect.rawValue, duration])
	}
	
	/// Sets power state for a device.
	/// - Parameters:
	///   - on: The power state you want your device to change to.
	///   - effect: An effect that wiil be used.
	///   - duration: Time that it will take.
	///   - device: A target device.
	public func setPower(
		to on: Bool,
		withEffect effect: ChangeEffect = .smooth,
		withDuration duration: Int = 500,
		withMode mode: TurnOnMode = .normal,
		for device: Device
	) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_power", params: [(on ? "on" : "off"), effect.rawValue, duration, mode.rawValue])
	}
	
	/// Sets power state for a device.
	/// - Parameters:
	///   - state: The power state you want your device to change to.
	///   - effect: An effect that wiil be used.
	///   - duration: Time that it will take.
	///   - device: A target device.
	public func setPower(
		to state: PowerState,
		withEffect effect: ChangeEffect = .smooth,
		withDuration duration: Int = 500,
		withMode mode: TurnOnMode = .normal,
		for device: Device
	) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_power", params: [state.rawValue, effect.rawValue, duration, mode.rawValue])
	}
	
	/// Toggles an LED.
	/// - Parameter device: A target device.
	public func togglePower(of device: Device) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "toggle", params: [])
	}
	
	public enum Action: Int {
		case recoverToPreviousState = 0
		case stayTheSame
		case shutDown
	}
	
	/// This method is used to save current state of smart LED in persistent memory. So if user powers off and then powers on the smart LED again (hard power reset), the smart LED will show last saved state.
	/// - Parameter device: Target device.
	public func saveCurrentStateAsDefault(for device: Device) async throws {
		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "set_default", params: [])
	}
	
	public func startColorFlow(of flow: [ColorFlowExpression], withCount count: Int, withAction action: Action, for device: Device) async throws {
		var flowString: String = ""
		for (index, element) in flow.enumerated() {
			switch element {
				case .color(let duration, let value, let brightness):
					var computedBrightness: Int {
						if brightness == nil {
							return -1
						} else {
							return brightness!
						}
					}
					
					flowString.append("\(duration), 1, \(((value.red << 16) + (value.green << 8) + value.blue)), \(computedBrightness)")
					if index != flow.count {
						flowString.append(",")
					}
				case .colorTemperature(let duration, let value, let brightness):
					var computedBrightness: Int {
						if brightness == nil {
							return -1
						} else {
							return brightness!
						}
					}
					
					flowString.append("\(duration), 2, \(((value.red << 16) + (value.green << 8) + value.blue)), \(computedBrightness)")
					if index != flow.count {
						flowString.append(",")
					}
				case .sleep(let duration, let value):
					flowString.append("\(duration), 7, \(((value.red << 16) + (value.green << 8) + value.blue)), 0")
					if index != flow.count {
						flowString.append(",")
					}
			}
		}

		let _ = try await runDeviceMethod(deviceId: device.deviceId, method: "start_cf", params: [count, action.rawValue, flowString])
	}
	
	private func runDeviceMethod(deviceId: String, method: String, params: Array<Any>) async throws -> Data {
		return try await self.sendDeviceRequest(
			url: URL(string: "https://\(self.region.rawValue).openapp.io.mi.com/openapp/device/rpc/\(deviceId)")!,
			arguments: ["method": method, "params": params]
		)
	}
	
	public func get(properties: [DeviceProperty], of device: Device) async throws -> [String] {
		var requestProps: [String] = []
		
		for prop in properties {
			requestProps.append(prop.rawValue)
		}
		
		let response = try await runDeviceMethod(deviceId: device.deviceId, method: "get_prop", params: requestProps)
		return try JSONDecoder().decode(BaseJsonModel<[String]>.self, from: response).result
	}
	
	public func get(property: DeviceProperty, of device: Device) async throws -> String {
		let response = try await runDeviceMethod(deviceId: device.deviceId, method: "get_prop", params: [property.rawValue])
		return try JSONDecoder().decode(BaseJsonModel<[String]>.self, from: response).result[0]
	}
	
	/// An internal function to pass requests to devices.
	/// - Parameters:
	///   - url: A url to call when making a request.
	///   - arguments: JSON arguments that will be stuffid in the request.
	/// - Returns: A response in Data type.
	private func sendDeviceRequest(url: URL, arguments: [String: Any]) async throws -> Data {
		do {
			let payload = try JSONSerialization.data(withJSONObject: arguments)
			let task = AF.request(
				url,
				method: .post,
				parameters: [
					"clientId": YeelightKit.clientId,
					"accessToken": self.accessToken,
					"data": String(data: payload, encoding: .utf8)!.replacingOccurrences(of: "\n", with: "")
				],
				headers: ["Content-Type": "application/x-www-form-urlencoded"]
			).serializingData()
			return try await task.value
		} catch {
			throw RequestError.badToken
		}
	}
}