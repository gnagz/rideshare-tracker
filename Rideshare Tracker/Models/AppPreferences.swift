import Foundation

class AppPreferences: ObservableObject {
    @Published var tankCapacity: Double = 14.3
    @Published var gasPrice: Double = 3.50
    @Published var standardMileageRate: Double = 0.70 // 2025 IRS rate
    
    init() {
        loadPreferences()
    }
    
    private func loadPreferences() {
        tankCapacity = UserDefaults.standard.double(forKey: "tankCapacity")
        if tankCapacity == 0 { tankCapacity = 14.3 }
        
        gasPrice = UserDefaults.standard.double(forKey: "gasPrice")
        if gasPrice == 0 { gasPrice = 3.50 }
        
        standardMileageRate = UserDefaults.standard.double(forKey: "standardMileageRate")
        if standardMileageRate == 0 { standardMileageRate = 0.70 }
    }
    
    func savePreferences() {
        UserDefaults.standard.set(tankCapacity, forKey: "tankCapacity")
        UserDefaults.standard.set(gasPrice, forKey: "gasPrice")
        UserDefaults.standard.set(standardMileageRate, forKey: "standardMileageRate")
    }
}
