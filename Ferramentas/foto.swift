// Pede pra Faxina (aberta com --fotos <pasta>) fotografar as janelas: ./foto <nome>
import Foundation

DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.eduardomoraes.faxina.foto"), object: CommandLine.arguments.dropFirst().first ?? "foto",
    userInfo: nil, deliverImmediately: true)
