
import SwiftUI

struct Database: View {
    func totalAcceleration (sensorNumber: Int) -> Double {
        let moveSensei: MovesenseAcceleration = load("testDataSensei\(sensorNumber).json")
        var sum = 0.0
        for i in 1...moveSensei.data.count {
            let x = moveSensei.data[i - 1].acc.arrayAcc[0].x
            let z = moveSensei.data[i - 1].acc.arrayAcc[0].z
            let y = moveSensei.data[i - 1].acc.arrayAcc[0].y
            
            let sqrtXZ = sqrt(x*x + z*z)
            let accXYZ = sqrt(y*y + sqrtXZ)
            sum += accXYZ
        }
        return sum / Double(moveSensei.data.count)
    }
    
    func totalAccelerationElevator (sensorNumber: Int) -> Double {
        let moveSensei: MovesenseAcceleration = load("testDataElevator\(sensorNumber).json")
        var sum = 0.0
        for i in 1...moveSensei.data.count {
            let x = moveSensei.data[i - 1].acc.arrayAcc[0].x
            let z = moveSensei.data[i - 1].acc.arrayAcc[0].z
            let y = moveSensei.data[i - 1].acc.arrayAcc[0].y
            
            let sqrtXZ = sqrt(x*x + z*z)
            let accXYZ = sqrt(y*y + sqrtXZ)
            sum += accXYZ
        }
        return sum / Double(moveSensei.data.count)
    }
    
    
    func averageX (sensorNumber: Int) -> Double {
        let moveSensei: MovesenseAcceleration = load("testDataSensei\(sensorNumber).json")
        var sum = 0.0
        for i in 1...moveSensei.data.count {
            sum += abs(moveSensei.data[i - 1].acc.arrayAcc[0].x)
        }
        return sum / Double(moveSensei.data.count)
    }
    

    
    func averageY (sensorNumber: Int) -> Double {
        let moveSensei: MovesenseAcceleration = load("testDataSensei\(sensorNumber).json")
        var sum = 0.0
        for i in 1...moveSensei.data.count {
            sum += abs(moveSensei.data[i - 1].acc.arrayAcc[0].y)
        }
        return sum / Double(moveSensei.data.count)
    }
    
    
    func averageZ (sensorNumber: Int) -> Double {
        let moveSensei: MovesenseAcceleration = load("testDataSensei\(sensorNumber).json")
        var sum = 0.0
        for i in 1...moveSensei.data.count {
            sum += abs(moveSensei.data[i - 1].acc.arrayAcc[0].z)
        }
        return sum / Double(moveSensei.data.count)
    }
    
    
    var body: some View {
        
        ScrollView {
            VStack {
                Text("Drill measurement 1: ")
                    .padding()
                Text("Movesense 206: ")
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2061))")
                    .padding()
               
                Text("Movesense 185: ")
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 1851))")
                    .padding()
               
            }
            Spacer()
            Spacer()
            VStack {
                Text("Drill measurement 2: ")
                    .padding()
                Text("Movesense 206: ")
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2062))")
                    .padding()
    
                Text("Movesense 185: ")
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 1852))")
                    .padding()
            }
            Spacer()
            VStack {
                Text("Elevator measurement 1: ")
                    .padding()
                Text("Movesense 206: ")
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2061))")
                    .padding()
                Spacer()
                Spacer()
                Text("Elevator measurement 2: ")
                Text("Movesense 206: ")
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2062))")
                    .padding()
            }
        }
    }
}


