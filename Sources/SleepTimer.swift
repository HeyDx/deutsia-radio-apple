import SwiftUI
struct SleepTimerView: View {
    @EnvironmentObject var s: RadioStore
    @Environment(\.dismiss) var dismiss
    @State var minutes = 30.0
    var body: some View {
        VStack(alignment:.leading,spacing:24) {
            Text("定时停止").font(.title2.bold())
            Text("\(Int(minutes)/60) 小时 \(Int(minutes)%60) 分钟").font(.title.monospacedDigit())
            Slider(value:$minutes,in:1...720,step:1)
            Stepper("\(Int(minutes)) 分钟",value:$minutes,in:1...720,step:1)
            HStack { Button("取消定时") { s.timerEnd = nil; dismiss() }; Spacer(); Button("开始计时") { s.timerEnd = Date().addingTimeInterval(minutes*60); dismiss() }.buttonStyle(.borderedProminent) }
        }.padding(30).frame(idealWidth:440)
    }
}
