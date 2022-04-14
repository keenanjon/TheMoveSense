
import SwiftUI

struct Database: View {
    
    var body: some View {
        
        ZStack {
            Image("factory")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
        
        ScrollView {
            VStack {
                Text("Drill measurement 1: ")
                    .padding()
                    .font(.title)
                Text("Movesense 206: ")
                    .fontWeight(.bold)
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2061))")
                    .padding()

                Text("Movesense 185: ")
                    .fontWeight(.bold)
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 1851))")
                    .padding()
            }
            Spacer()
            VStack {
                Text("Drill measurement 2: ")
                    .padding()
                    .font(.title)
                Text("Movesense 206: ")
                    .fontWeight(.bold)
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2062))")
                    .padding()

                Text("Movesense 185: ")
                    .fontWeight(.bold)
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 1852))")
                    .padding()
            }
            Spacer()
            VStack {
                Text("Elevator measurement 1: ")
                    .padding()
                    .font(.title)
                Text("Movesense 206: ")
                    .fontWeight(.bold)
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2061))")
                    .padding()
                Spacer()
                Text("Elevator measurement 2: ")
                    .padding()
                    .font(.title)
                Text("Movesense 206: ")
                    .fontWeight(.bold)
                Text("Total acceleration: \(totalAcceleration(sensorNumber: 2062))")
                    .padding()
            }
        }
        .foregroundColor(Color.white)
        .frame(maxWidth: .infinity)
        .background(
            .indigo
                .opacity(0.9)
        )
        .cornerRadius(10)
        .padding()
    }
}
}
    


