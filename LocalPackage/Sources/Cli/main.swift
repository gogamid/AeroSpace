import Socket
import Foundation
import Common
import Darwin

initCli()

func printVersionAndExit(serverVersion: String?) -> Never {
    print(
        """
        aerospace CLI client version: \(cliClientVersionAndHash)
        AeroSpace.app server version: \(serverVersion ?? "Unknown. The server is not running")
        """
    )
    exit(0)
}

let args: [String] = Array(CommandLine.arguments.dropFirst())

for arg in args {
    if arg.contains(" ") || arg.contains("\n") {
        prettyError("Spaces and newlines in arguments are not permitted. '\(arg)' argument contains either of them.")
    }
}

let usage =
    """
    usage: \(CommandLine.arguments.first ?? "aerospace") [-h|--help] [-v|--version] <command> [<args>...]

    For the list of all available commands see:
    - https://github.com/nikitabobko/AeroSpace/blob/main/docs/commands.md
    - https://github.com/nikitabobko/AeroSpace/blob/main/docs/cli-commands.md
    """
if args.isEmpty || args.first == "--help" || args.first == "-h" {
    print(usage)
} else {
    let argsAsString = args.joined(separator: " ")

    let isVersion: Bool
    switch parseCmdArgs(argsAsString) {
    case .cmd(let cmdArgs):
        isVersion = cmdArgs is VersionCmdArgs
    case .help(let help):
        print(help)
        exit(0)
    case .failure(let e):
        print(e)
        exit(1)
    }

    let socket = tryCatch { try Socket.create(family: .unix, type: .stream, proto: .unix) }.getOrThrow()
    defer {
        socket.close()
    }
    let socketFile = "/tmp/\(appId).sock"
    if let e: AeroError = tryCatch(body: { try socket.connect(to: socketFile) }).errorOrNil {
        if isVersion {
            printVersionAndExit(serverVersion: nil)
        } else {
            prettyError("Can't connect to AeroSpace server. Is AeroSpace.app running?\n\(e.msg)")
        }
    }

    func run(_ command: String, stdin: String) -> (Int32, String) {
        tryCatch { try socket.write(from: command + "\n" + stdin) }.getOrThrow()
        tryCatch { try Socket.wait(for: [socket], timeout: 0, waitForever: true) }.getOrThrow()
        let received: String = tryCatch { try socket.readString() }.getOrThrow()
            ?? prettyErrorT("fatal error: received nil from socket")
        let exitCode: Int32 = received.first.map { String($0) }.flatMap { Int32($0) } ?? 1
        let output = String(received.dropFirst())
        return (exitCode, output)
    }

    let (internalExitCode, serverVersionAndHash) = run("version", stdin: "")
    if internalExitCode != 0 {
        prettyError("Client-server miscommunication error: \(serverVersionAndHash)")
    }
    if serverVersionAndHash != cliClientVersionAndHash {
        prettyError(
            """
            AeroSpace client/server version mismatch

            - aerospace CLI client version: \(cliClientVersionAndHash)
            - AeroSpace.app server version: \(serverVersionAndHash)

            Possible fixes:
            - Restart AeroSpace.app (restart is required after each update)
            - Reinstall and restart AeroSpace (corrupted installation)
            """
        )
    }

    if isVersion {
        printVersionAndExit(serverVersion: serverVersionAndHash)
    }

    var stdin = ""
    if !isATty(STDIN_FILENO) {
        var index = 0
        while let line = readLine(strippingNewline: false) {
            stdin += line
            index += 1
            if index > 1000 {
                prettyError("stdin number of lines limit is exceeded")
            }
        }
    }

    let (exitCode, output) = run(argsAsString, stdin: stdin)

    print(output)
    exit(exitCode)
}