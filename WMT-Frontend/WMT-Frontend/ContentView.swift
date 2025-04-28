import SwiftUI
import MapKit
import CoreLocation

// MARK: - Модели данных

struct CountryStatus: Codable, Identifiable {
    let id: Int?
    let country: Int
    let countryName: String?
    let status: String
    let latitude: Double
    let longitude: Double
    
    enum CodingKeys: String, CodingKey {
        case id, country, status, latitude, longitude
        case countryName = "country_name"
    }
}

struct Country: Codable, Identifiable {
    let id: Int
    let name: String
    let isoCode: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case isoCode = "iso_code"
    }
}

struct AuthToken: Codable {
    let token: String
}

struct CountryMarker: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let status: String // "visited" или "want_to_visit"
    let countryId: Int?
    let statusId: Int? // ID записи статуса в API
}

// MARK: - API Сервис

class ApiService: ObservableObject {
    // URL вашего API
    private let baseURL: String
    
    @Published var authToken: String?
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    @Published var visitedCountries: [CountryMarker] = []
    @Published var wantToVisitCountries: [CountryMarker] = []
    @Published var countries: [Country] = []
    
    init(baseURL: String = "http://127.0.0.1:8000") {
        self.baseURL = baseURL
        
        
        if let savedToken = UserDefaults.standard.string(forKey: "authToken") {
            self.authToken = savedToken
            self.isLoggedIn = true
            self.fetchCountries()
            self.fetchCountryStatuses()
        }
    }
    
    // log
    func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        self.isLoading = true
        let url = URL(string: "\(baseURL.replacingOccurrences(of: "/api", with: ""))/api-token-auth/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = ["username": username, "password": password]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                do {
                    let authResponse = try JSONDecoder().decode(AuthToken.self, from: data)
                    self.authToken = authResponse.token
                    UserDefaults.standard.setValue(authResponse.token, forKey: "authToken")
                    self.isLoggedIn = true
                    
                    // Получаем списки стран и статусов
                    self.fetchCountries()
                    self.fetchCountryStatuses()
                    
                    completion(true)
                } catch {
                    self.errorMessage = "Error decoding response: \(error.localizedDescription)"
                    completion(false)
                }
            }
        }.resume()
    }
    
    //
    func register(username: String, email: String, password: String, completion: @escaping (Bool) -> Void) {
        self.isLoading = true
        let url = URL(string: "\(baseURL)/register/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: String] = [
            "username": username,
            "email": email,
            "password": password
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Network error: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server error: \(httpResponse.statusCode)"
                    completion(false)
                    return
                }
                
                // Успешная регистрация, теперь входим с этими данными
                self.login(username: username, password: password, completion: completion)
            }
        }.resume()
    }
    
    //
    func logout() {
        self.authToken = nil
        self.isLoggedIn = false
        UserDefaults.standard.removeObject(forKey: "authToken")
        self.visitedCountries = []
        self.wantToVisitCountries = []
    }
    
    
    func fetchCountries() {
        guard let token = authToken else { return }
        
        let url = URL(string: "\(baseURL)/countries/")!
        var request = URLRequest(url: url)
        request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Error fetching countries: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let countriesResponse = try JSONDecoder().decode([Country].self, from: data)
                    self.countries = countriesResponse
                } catch {
                    self.errorMessage = "Error decoding countries: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    
    func fetchCountryStatuses() {
        guard let token = authToken else { return }
        
        self.isLoading = true
        let url = URL(string: "\(baseURL)/country-statuses/")!
        var request = URLRequest(url: url)
        request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error fetching statuses: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    let statusesResponse = try JSONDecoder().decode([CountryStatus].self, from: data)
                    
                    // Очищаем текущие списки
                    self.visitedCountries = []
                    self.wantToVisitCountries = []
                    
                    // Заполняем списки новыми данными
                    for status in statusesResponse {
                        let marker = CountryMarker(
                            name: status.countryName ?? "Unknown",
                            coordinate: CLLocationCoordinate2D(latitude: status.latitude, longitude: status.longitude),
                            status: status.status,
                            countryId: status.country,
                            statusId: status.id
                        )
                        
                        if status.status == "visited" {
                            self.visitedCountries.append(marker)
                        } else if status.status == "want_to_visit" {
                            self.wantToVisitCountries.append(marker)
                        }
                    }
                } catch {
                    self.errorMessage = "Error decoding statuses: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    // Добавление нового статуса страны
    func addCountryStatus(countryName: String, countryId: Int?, status: String, latitude: Double, longitude: Double, completion: @escaping (Bool) -> Void) {
        guard let token = authToken, let countryId = countryId else {
            DispatchQueue.main.async {
                self.errorMessage = "Not logged in or invalid country"
                completion(false)
            }
            return
        }
        
        self.isLoading = true
        let url = URL(string: "\(baseURL)/country-statuses/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "country": countryId,
            "status": status,
            "latitude": latitude,
            "longitude": longitude
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error adding status: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    if (200...299).contains(httpResponse.statusCode) {
                        // Обновляем списки стран
                        self.fetchCountryStatuses()
                        completion(true)
                    } else {
                        if let data = data, let errorMessage = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let error = errorMessage["error"] as? String {
                            self.errorMessage = error
                        } else {
                            self.errorMessage = "Server error: \(httpResponse.statusCode)"
                        }
                        completion(false)
                    }
                } else {
                    self.errorMessage = "Unknown error"
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Удаление статуса страны
    func deleteCountryStatus(statusId: Int, completion: @escaping (Bool) -> Void) {
        guard let token = authToken else {
            DispatchQueue.main.async {
                self.errorMessage = "Not logged in"
                completion(false)
            }
            return
        }
        
        self.isLoading = true
        let url = URL(string: "\(baseURL)/country-statuses/\(statusId)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("Token \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error deleting status: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    // Обновляем списки стран
                    self.fetchCountryStatuses()
                    completion(true)
                } else {
                    self.errorMessage = "Server error"
                    completion(false)
                }
            }
        }.resume()
    }
    
    // Reverse Geocoding для получения страны по координатам
    func findCountryByCoordinates(location: CLLocationCoordinate2D, completion: @escaping (String?, Int?) -> Void) {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        geocoder.reverseGeocodeLocation(loc) { placemarks, error in
            DispatchQueue.main.async {
                if let country = placemarks?.first?.country {
                    // Ищем страну в нашем списке
                    let matchingCountry = self.countries.first { $0.name.lowercased() == country.lowercased() }
                    completion(country, matchingCountry?.id)
                } else {
                    completion(nil, nil)
                }
            }
        }
    }
}

// MARK: - Представления

// Экран входа
struct LoginView: View {
    @ObservedObject var apiService: ApiService
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var isRegistering = false
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "map")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                Text(isRegistering ? "Create Account" : "Welcome Back")
                    .font(.largeTitle)
                    .bold()
                
                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    
                    if isRegistering {
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .textContentType(.emailAddress)  // Вместо keyboardType
                            
                    }
                    
                    SecureField("Password", text: $password)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    if isRegistering {
                        apiService.register(username: username, email: email, password: password) { success in
                            if !success {
                                showAlert = true
                            }
                        }
                    } else {
                        apiService.login(username: username, password: password) { success in
                            if !success {
                                showAlert = true
                            }
                        }
                    }
                }) {
                    Text(isRegistering ? "Register" : "Login")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .disabled(apiService.isLoading)
                
                if apiService.isLoading {
                    ProgressView()
                        .padding()
                }
                
                Button(action: {
                    isRegistering.toggle()
                }) {
                    Text(isRegistering ? "Already have an account? Login" : "New user? Create account")
                        .foregroundColor(.blue)
                }
                .padding(.top)
                
                Spacer()
            }
            .padding()
            #if os(iOS) || os(tvOS)
                .navigationBarHidden(true)
            #endif
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(apiService.errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

// Главный экран с картой
struct ContentView: View {
    @StateObject private var apiService = ApiService()
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
    )
    @State private var showingStatusPicker = false
    @State private var selectedCoordinate = CLLocationCoordinate2D()
    @State private var selectedCountryName = ""
    @State private var selectedCountryId: Int? = nil
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showLogoutConfirmation = false
    
    var allCountries: [CountryMarker] {
        return apiService.visitedCountries + apiService.wantToVisitCountries
    }
    
    var body: some View {
        Group {
            if !apiService.isLoggedIn {
                LoginView(apiService: apiService)
            } else {
                NavigationView {
                    ScrollView {
                        VStack(spacing: 20) {
                            // КАРТА
                            ZStack {
                                Map(coordinateRegion: $region, annotationItems: allCountries) { country in
                                    MapAnnotation(coordinate: country.coordinate) {
                                        VStack {
                                            Circle()
                                                .fill(country.status == "visited" ? Color.orange : Color.green)
                                                .frame(width: 15, height: 15)
                                                .shadow(radius: 2)
                                            
                                            Text(country.name)
                                                .font(.caption)
                                                .fixedSize()
                                                .background(Color.white.opacity(0.7))
                                                .cornerRadius(4)
                                        }
                                        .onTapGesture {
                                            if let statusId = country.statusId {
                                                showRemoveCountryAlert(country.name, statusId: statusId)
                                            }
                                        }
                                    }
                                }
                                .frame(height: 300)
                                .cornerRadius(15)
                                .shadow(radius: 5)
                                .gesture(
                                    TapGesture()
                                        .onEnded { _ in
                                            let tapCoordinate = region.center
                                            apiService.findCountryByCoordinates(location: tapCoordinate) { countryName, countryId in
                                                if let countryName = countryName {
                                                    selectedCountryName = countryName
                                                    selectedCountryId = countryId
                                                    selectedCoordinate = tapCoordinate
                                                    showingStatusPicker = true
                                                } else {
                                                    alertMessage = "Could not find a country at this location"
                                                    showAlert = true
                                                }
                                            }
                                        }
                                )
                                
                                if apiService.isLoading {
                                    Color.white.opacity(0.5)
                                    ProgressView()
                                }
                                
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            apiService.fetchCountryStatuses()
                                        }) {
                                            Image(systemName: "arrow.clockwise.circle.fill")
                                                .resizable()
                                                .frame(width: 40, height: 40)
                                                .foregroundColor(.blue)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(Circle())
                                                .shadow(radius: 3)
                                        }
                                        .padding(.trailing)
                                        .padding(.bottom)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // ЛЕГЕНДА
                            HStack(spacing: 20) {
                                HStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 15, height: 15)
                                    Text("Visited")
                                        .font(.caption)
                                }
                                
                                HStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 15, height: 15)
                                    Text("Want to Visit")
                                        .font(.caption)
                                }
                                
                                Spacer()
                                
                                Text("Tap country to remove")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal)
                            
                            // СПИСКИ СТРАН
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Visited Countries")
                                    .font(.title2)
                                    .bold()
                                    .padding(.leading)
                                
                                if apiService.visitedCountries.isEmpty {
                                    Text("No visited countries yet. Tap the map to add!")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                } else {
                                    ForEach(apiService.visitedCountries) { country in
                                        HStack {
                                            Text(country.name)
                                                .foregroundColor(.orange)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                if let statusId = country.statusId {
                                                    apiService.deleteCountryStatus(statusId: statusId) { _ in }
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color.orange.opacity(0.1))
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                    }
                                }
                                
                                Divider()
                                    .padding(.horizontal)
                                
                                Text("Want to Visit")
                                    .font(.title2)
                                    .bold()
                                    .padding(.leading)
                                
                                if apiService.wantToVisitCountries.isEmpty {
                                    Text("No countries in your wishlist. Tap the map to add!")
                                        .foregroundColor(.gray)
                                        .padding(.horizontal)
                                } else {
                                    ForEach(apiService.wantToVisitCountries) { country in
                                        HStack {
                                            Text(country.name)
                                                .foregroundColor(.green)
                                            
                                            Spacer()
                                            
                                            Button(action: {
                                                if let statusId = country.statusId {
                                                    apiService.deleteCountryStatus(statusId: statusId) { _ in }
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                        .background(Color.green.opacity(0.1))
                                        .cornerRadius(8)
                                        .padding(.horizontal)
                                    }
                                }
                            }
                            .padding(.bottom)
                        }
                    }
                    .navigationTitle("World Map Tracker")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button(action: {
                                showLogoutConfirmation = true
                            }) {
                                Image(systemName: "person.crop.circle.badge.xmark")
                            }
                        }
                    }
                    .alert(isPresented: $showingStatusPicker) {
                        Alert(
                            title: Text("Add \(selectedCountryName)"),
                            message: Text("Choose a category"),
                            primaryButton: .default(Text("Visited")) {
                                addCountry(status: "visited")
                            },
                            secondaryButton: .default(Text("Want to Visit")) {
                                addCountry(status: "want_to_visit")
                            }
                        )
                    }
                    .alert("Error", isPresented: $showAlert, actions: {
                        Button("OK", role: .cancel) {}
                    }, message: {
                        Text(alertMessage)
                    })
                    .alert("Log Out", isPresented: $showLogoutConfirmation, actions: {
                        Button("Cancel", role: .cancel) {}
                        Button("Log Out", role: .destructive) {
                            apiService.logout()
                        }
                    }, message: {
                        Text("Are you sure you want to log out?")
                    })
                    .onAppear {
                        apiService.fetchCountryStatuses()
                    }
                }
            }
        }
    }
    
    func addCountry(status: String) {
        apiService.addCountryStatus(
            countryName: selectedCountryName,
            countryId: selectedCountryId,
            status: status,
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude
        ) { success in
            if !success {
                alertMessage = apiService.errorMessage
                showAlert = true
            }
        }
    }
    
    func showRemoveCountryAlert(_ countryName: String, statusId: Int) {
        alertMessage = "Remove \(countryName) from your list?"
        showAlert = true
        
        // Тут нужна логика удаления страны
        // apiService.deleteCountryStatus(statusId: statusId) { _ in }
    }
}

// Предпросмотр для SwiftUI
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
