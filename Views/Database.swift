
import SwiftUI

struct Database: View {
    
    
    
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


