
function restoreHiScore {
    param (
        [String] $filename
    )

    [Int] $hidata = 0
    try {
        $hidata = Import-Clixml -Path $filename -ErrorAction Stop
    } catch {
        return 0
    }
    return $hiData
}

function saveHiScore {
    param (
        [string] $filename,
        [Int] $hi
    )

    try {
        Export-Clixml -Path $filename -InputObject $hi -ErrorAction Stop -Force
    } catch {
        write-host ("oops. {0} not saved" -f $filename)
    }
}

function registerScore {
    param (
        [Int] $hi,
        [Int] $score
    )

    if ($score -gt $hi) {
        return $score
    }
    return $hi
}

function isOsUnix {
    return ($PSVersionTable.ContainsKey("Platform") -and 
            $PSVersionTable["Platform"] -eq "Unix")
}

function setStty {
    [String] $sttystate = ""
    if (isOsUnix) {
        try {
            $sttystate = stty --save
            stty -echo
        } catch {
        }
    }

    if ($null -eq $sttystate) {
        $sttystate = ""
    }

    return $sttystate
}

function resetStty {
    param (
        [String] $sttystate
    )

    if ((isOsUnix) -and $sttystate -ne "") {
        try {
            stty $sttystate
        } catch {
        }
    }
}

function isWindowSmall {
    return [Console]::WindowHeight -lt 24 -or [Console]::WindowWidth -lt 64
}

function isWindowNormalized {
    $resized = $false
    while (isWindowSmall) {
        $resized = $true
        [Console]::SetCursorPosition(0,0)
        [Console]::Write("Inrease window size!")
        start-sleep -Milliseconds 250
        [Console]::Clear()
        start-sleep -Milliseconds 250
    }
    return $resized
}

function getCenterMargin {
    param (
        [int] $len
    )

    $x = [Math]::Truncate([Console]::WindowWidth / 2 - $len / 2)
    if ($x -lt 0) {
        return 0
    }

    return $x
}

function getGreetingTop {
    return [Math]::Truncate([Console]::WindowHeight * .7)
}

function writeGreeting {
    param (
        [string] $txt
    )

    [Int] $x = getCenterMargin $txt.Length
    [Int] $y = getGreetingTop
    [Console]::SetCursorPosition($x, $y)
    setColorNormal
    [Console]::Write($txt)
}

function writeResult {
    param (
        [Int] $hi,
        [Int] $score
    )

    [String] $txt = "hi: {0,-10} score: {1,-10}" -f $hi, $score
    [Int] $x = getCenterMargin $txt.Length
    [Console]::SetCursorPosition(0, 0)
    setColorTitle
    [Console]::Write($txt.PadLeft($txt.length + $x).PadRight([Console]::WindowWidth - 1))
    setColorNormal
}

function writeTitle {
    param (
        [hashtable] $st,
        [Int] $complete
    )

    [String] $txt = "hi: {0,-5} score: {1,-5} level: {2,-3} lives: {3,-3} complete: {4}%" -f
                    $st.hi, $st.score, $st.level, $st.lives, $complete
    [Int] $x = getCenterMargin $txt.Length
    [Console]::SetCursorPosition(0, 0)
    setColorTitle
    [Console]::Write($txt.PadLeft($txt.length + $x).PadRight([Console]::WindowWidth - 1))
    setColorNormal
}

function tryagain {
    param (
        [Int] $hi,
        [Int] $score
    )

    $geo = newGeometry
    [Boolean] $repeat = $true

    while ($repeat) {
        if ((isGeometryChanged $geo) -or (isWindowNormalized)) {
            $geo = getGeometry
            clearConsole
            writeResult $hi $score
            writeGreeting "Q - quit,  SPACE - play"
        }
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            $repeat = $false
        } else {
            Start-Sleep -Milliseconds 250
        }
    }
    return $key.Key -ne [ConsoleKey]::Q
}

function setColorTitle {
    [Console]::ForegroundColor = "White"
    [Console]::BackgroundColor = "DarkGray"
}

function setColorNormal {
    [Console]::ForegroundColor = "Gray"
    [Console]::BackgroundColor = "Black"
}

function setColorInverted {
    [Console]::ForegroundColor = "Black"
    [Console]::BackgroundColor = "Gray"
}

function clearConsole {
    [Console]::CursorVisible = $false
    setColorNormal
    [Console]::Clear()
}

function prepareConsole {
    [hashtable] $consoleState = @{
            sttyState = setStty;
            TreatControlCAsInput = [console]::TreatControlCAsInput
        }
    [console]::TreatControlCAsInput = $true
    clearConsole
    return $consoleState
}

function restoreConsole {
    param (
        [hashtable] $controlState
    )

    resetStty $controlState.sttyState
    [Console]::CursorVisible = $true
    [console]::TreatControlCAsInput = $controlState.TreatControlCAsInput
    [Console]::ResetColor()
    [Console]::Clear()
}

function newGeometry {
    return @{left = -1; top = -1; width = -1; height = -1}
}

function getGeometry {
    return @{
            left = [Console]::WindowLeft; 
            top = [Console]::WindowTop; 
            width = [Console]::WindowWidth; 
            height = [Console]::WindowHeight
        }
}

function isGeometryChanged {
    param (
        [hashtable] $o
    )

    $n = getGeometry
    return ($o.left -ne $n.left -or 
            $o.top -ne $n.top -or 
            $o.width -ne $n.width -or 
            $o.height -ne $n.height)
}

function getOnePercentValue {
    param (
        [Int] $total
    )

    [Int] $onePercent = [Math]::Truncate($total / 100)
    if ($onePercent -lt 1) {
        $onePercent = 1
    }
    return $onePercent
}

function getTogo {
    param (
        [Int] $level,
        [Int] $onePercent
    )

    [Int] $bonus = [Math]::Truncate($onePercent * [Math]::Min($level, 100) / 10)
    return $onePercent * 75 - $bonus
}

function fillAndDrawBorders {
    param (
        [int[,]] $f
    )

    setColorInverted
    $maxy = $f.GetLength(1) - 1
    for ($o = 0; $o -lt 4; $o++) {
        [Console]::SetCursorPosition(0, ($o + 1))
        for ($x = 0; $x -lt $f.GetLength(0); $x++) {
            $f[$x, $o] = 1
            [Console]::Write('.')
        }
    }

    for ($o = 3; $o -ge 0; $o--) {
        $y = $maxy - $o
        [Console]::SetCursorPosition(0, ($y + 1))
        for ($x = 0; $x -lt $f.GetLength(0); $x++) {
            $f[$x, $y] = 1
            [Console]::Write('.')
        }
    }

    $maxx = $f.GetLength(0) - 1
    for ($y = 4; $y -lt $f.GetLength(1) - 4; $y++) {
        [Console]::SetCursorPosition(0, ($y + 1))
        for ($o = 0; $o -lt 4; $o++) {
            $f[$o, $y] = 1
            [Console]::Write('.')
        }

        [Console]::SetCursorPosition(($maxx - 3), ($y + 1))
        for ($o = 3; $o -ge 0; $o--) {
            $f[($maxx - $o), $y] = 1
            [Console]::Write('.')
        }
    }

    return ($f.GetLength(0) - 8) * 8  + $f.GetLength(1) * 8
}

function showActor {
    param (
        [hashtable] $actor
    )

    [Console]::SetCursorPosition($actor.x, $actor.y + 1)
    if ($actor.side -eq 0) {
        [Console]::Write('O')
    } else {
        setColorInverted
        [Console]::Write('X')
        setColorNormal
    }
}

function showPlayer {
    param (
        [int[,]] $f,
        [hashtable] $player
    )

    [Console]::SetCursorPosition($player.x, $player.y + 1)
    if ($player.side -eq 0) {
        [Console]::Write('*')
    } else {
        setColorInverted
        [Console]::Write('*')
        setColorNormal
    }
}

function showCell {
    param (
        [int[,]] $f,
        [Int] $x,
        [Int] $y
    )

    [Console]::SetCursorPosition($x, $y + 1)
    if (($f[$x, $y] -band 1) -eq 0) {
        if (($f[$x, $y] -band 8) -eq 0) {
            [Console]::Write(' ')
        } else {
            [Console]::Write('+')
        }
    } else {
        setColorInverted
        [Console]::Write('.')
        setColorNormal
    }
}

function getIdleTimeout {
    return (Get-Date).AddSeconds(5)
}

function newPlayer {
    param (
        $x = 0, $y = 0, $oldx = 0, $oldy = 0, $dx = 0, $dy = 0, 
        $side = 1, $dead = $false, $idleTimeout = (getIdleTimeout)
    )

    return @{x = $x; y = $y; oldx = $oldx; oldy = $oldy; dx = $dx; dy = $dy;
            side = $side; dead = $dead; idleTimeout = $idleTimeout}
}

function setPlayer {
    param (
        [int[,]] $f
    )

    $x = [Math]::Truncate($f.GetLength(0) / 2)
    $y = 3
    [hashtable] $player = newPlayer -x $x -y $y -oldx $x -oldy $y
    showPlayer $f $player
    return $player
}

function revivePlayer {
    param (
        [int[,]] $f,
        [hashtable] $player    
    )

    $player.x = $player.oldx
    $player.y = $player.oldy
    $player.side = 1
    $player.dead = $false
    setPlayerDirection $player 0 0 $true
    showPlayer $f $player
}

function getCandidate {
    param (
        [int[,]] $f,
        [Int] $side
    )

    if ($side -eq 0) {
        $x = Get-Random -Minimum 4 -Maximum ($f.GetLength(0) - 4)
        $y = Get-Random -Minimum 4 -Maximum ($f.GetLength(1) - 4)
    } else {
        $borders = @(@(0, 0, ($f.GetLength(0)), 4),
                     @(0, ($f.GetLength(1) - 4), ($f.GetLength(0)), ($f.GetLength(1))),
                     @(0, 4, 4, ($f.GetLength(1) - 4)),
                     @(($f.GetLength(0) - 4), 4, ($f.GetLength(0)), ($f.GetLength(1) - 4))
                    )
        $bn = Get-Random -Maximum $borders.Count
        $x = Get-Random -Minimum $borders[$bn][0] -Maximum $borders[$bn][2]
        $y = Get-Random -Minimum $borders[$bn][1] -Maximum $borders[$bn][3]
    }

    $directions = @(@(-1, -1), @(-1, 1), @(1, -1), @(1, 1))
    $dx, $dy = $directions[(Get-Random -Maximum 4)]
    return @{side = $side; x = $x; y = $y; dx = $dx; dy = $dy; dead = $false}
}

function actorAbsent {
    param (
        [hashtable] $newbie,
        [Collections.ArrayList] $actors
    )

    ForEach ($actor in $actors) {
        $found = $true
        foreach ($key in @("x", "y")) {
            if ($actor[$key] -ne $newbie[$key]) {
                $found = $false
                break
            }
        }
        if ($found) {
            return $false
        }
    }
    return $true
}

function genActor {
    param (
        [int[,]] $f,
        [Collections.ArrayList] $actors,
        [Int] $side
    )

    for ($i = 0; $i -lt 1000; $i++ ) {
        $newbie = getCandidate $f $side
        if (actorAbsent $newbie $actors) {
            return $newbie
        }
    }

    return $null
}

function removeFromField {
    param (
        [int[,]] $f,
        [hashtable] $actor
    )

    $f[$actor.x, $actor.y] = $f[$actor.x, $actor.y] -band -bnot (2 -shl $actor.side)
}

function putToField {
    param (
        [int[,]] $f,
        [hashtable] $actor
    )

    $f[$actor.x, $actor.y] = $f[$actor.x, $actor.y] -bor (2 -shl $actor.side)
}

function lookForCollision {
    param (
        [int[,]] $f,
        [hashtable] $actor
    )

    if ($actor.side -eq 0) {
        return
    }

    $mask = 4   ## 2 -shl 1 * $actor.side
    $x = $actor.x + $actor.dx
    $y = $actor.y + $actor.dy
    if (($f[$x, $y] -band $mask) -eq $mask) {
        removeFromField $f $actor
        $actor.dead = $true
    }
}

function getVacant {
    param (
        [Collections.ArrayList] $actors
    )

    for ($i = 0; $i -lt $actors.Count; $i++) {
        if ($actors[$i].dead) {
            return $i
        }
    }
    return -1
}

function newActor {
    param (
        [int[,]] $f,
        [Collections.ArrayList] $actors,
        [Int] $side
    )

    $newbie = genActor $f $actors $side
    if ($null -eq $newbie) {
        return
    }
    $vacancy = getVacant $actors
    if ($vacancy -lt 0) {
        if ($actors.Count -lt 200) {
            $actors.add($newbie) | out-null
            putToField $f $newbie
            showActor $newbie
        }
    } else {
        $actors[$vacancy] = $newbie
        putToField $f $newbie
        showActor $newbie
    }
}

function setActors {
    param (
        [int[,]] $f,
        [int] $level
    )

    [Collections.ArrayList] $actors = [Collections.ArrayList]::new()
    [Int] $count = [Math]::Min($level, 100)
    [Int] $countQ = 1 + [Math]::Truncate($count / 3)
    for ($i = 0; $i -lt $countQ; $i++) {
        newActor $f $actors 1
    }

    for ($i = 0; $i -lt $count; $i++) {
        newActor $f $actors 0
    }

    return $actors
}

function takeStepActor {
    param (
        [int[,]] $f,
        [hashtable] $actor
    )

    removeFromField $f $actor
    $actor.x += $actor.dx
    $actor.y += $actor.dy
    putToField $f $actor
}

function isOutOfField {
    param (
        [int[,]] $f,
        [Int] $x,
        [Int] $y
    )

    return ($x -lt 0 -or 
            $x -ge $f.GetLength(0) -or
            $y -lt 0 -or
            $y -ge $f.GetLength(1))
}

function canMove {
    param (
        [int[,]] $f,
        [hashtable] $actor,
        [Int] $dx,
        [Int] $dy
    )

    $x = $actor.x + $dx
    $y = $actor.y + $dy

    if ($x -lt 0 -or $x -ge $f.GetLength(0) -or $y -lt 0 -or $y -ge $f.GetLength(1)) {
        return $false
    }

    if ($actor.side -eq 0) {
        $mask = 2
        if (($f[$x, $y] -band $mask) -eq $mask) {
            return $false
        }
    }

    return ($f[$x,$y] -band 1) -eq $actor.side
}

function getDirections {
    param (
        [int[,]] $f,
        [hashtable] $actor
    )

    $dirs = 0
    if (canMove $f $actor (-$actor.dx) $actor.dy) {
        $dirs = $dirs -bor 1
    }
    if (canMove $f $actor $actor.dx (-$actor.dy)) {
        $dirs = $dirs -bor 2
    }
    if (canMove $f $actor (-$actor.dx) (-$actor.dy)) {
        $dirs = $dirs -bor 4
    }
    return $dirs
}

function isDirectionFound {
    param (
        [int[,]] $f,
        [hashtable] $actor
    )

    if (canMove $f $actor $actor.dx $actor.dy) {
        return $true
    }
    [int] $dirs = getDirections $f $actor
    if ($dirs -eq 0) {
        return $false
    }
    [hashtable] $dhmt = @{1 = @(-1, 1); 2 = @(1, -1); 4 = @(-1, -1)}
    if ($dhmt.ContainsKey($dirs)) {
        $actor.dx *= $dhmt[$dirs][0]
        $actor.dy *= $dhmt[$dirs][1]
        return $true
    }
    $mdx = $mdy = 1
    if (-not (canMove $f $actor $actor.dx 0)) {
        if (canMove $f $actor (-$actor.dx) $actor.dy) {
            $mdx = -1
        }
    }
    if (-not (canMove $f $actor 0 $actor.dy)) {
        if (canMove $f $actor ($actor.dx * $mdx) (-$actor.dy)) {
            $mdy = -1
        }
    }
    if (($mdx -eq 1) -and ($mdy -eq 1)) {
        $mdx = $mdy = -1
    }
    $actor.dx *= $mdx
    $actor.dy *= $mdy
    return $true
}

function lookForPlayer {
    param (
        [int[,]] $f,
        [hashtable] $player,
        [hashtable] $actor
    )

    if (($f[$actor.x, $actor.y] -band 8) -ne 0) {
        paintTrack $f $actor.x $actor.y 0 | Out-Null
        showCell $f $player.x $player.y
        $player.dead = $true
        return
    }

    if ($player.x -eq $actor.x -and $player.y -eq $actor.y) {
        $player.dead = $true
        removeFromField $f $actor
        $actor.dead = $true
        showCell $f $player.x $player.y
    }
}

function moveActor {
    param (
        [int[,]] $f,
        [hashtable] $player,
        [hashtable] $actor
    )

    if ($actor.dead) {
        return
    }
    if (isDirectionFound $f $actor) {
        lookForCollision $f $actor
        showCell $f $actor.x $actor.y
        if ($actor.dead) {
            return
        }
        takeStepActor $f $actor
        lookForPlayer $f $player $actor
        if ($actor.dead) {
            return
        }
        showActor $actor
    }
}

function isLazyPlayer {
    param (
        [hashtable] $player
    )

    return ($player.idleTimeout -lt (Get-Date))
}

function playerMustKeeoMoving {
    param (
        [int[,]] $f,
        [hashtable] $player,
        [Collections.ArrayList] $actors
    )

    if (-not (isPlayerMoving $player) -and (isLazyPlayer $player)) {
        newActor $f $actors 1
        $player.idleTimeout = getIdleTimeout
    }
}

function markCell {
    param (
        [int[,]] $f,
        [hashtable] $player
    )

    if (($f[$player.x, $player.y] -band 1) -eq 0) {
        $f[$player.x, $player.y] = $f[$player.x, $player.y] -bor 8
    }
}

function paintTrack {
    param (
        [int[,]] $f,
        [Int] $x,
        [Int] $y,
        [Int] $side
    )

    [Int] $result = 0
    $coordSt = [Collections.Stack]::new()
    $coordSt.Push(@($x, $y))
    while ($coordSt.Count -ne 0) {
        $c, $r = $coordSt.Pop()
        if ($f[$c, $r] -lt 8) {
            continue
        }
        $result++
        $f[$c, $r] = $side
        showCell $f $c $r
        $coordSt.Push(@(($c - 1), $r))
        $coordSt.Push(@(($c + 1), $r))
        $coordSt.Push(@($c, ($r - 1)))
        $coordSt.Push(@($c, ($r + 1)))
    }
    return $result
}

function tryMark {
    param (
        [int[,]] $f,
        [Int] $x,
        [Int] $y,
        [Int] $enemyMask,
        [Int] $oldMark,
        [Int] $newMark
    )

    $coordSt = [Collections.Stack]::new()
    $coordSt.Push(@($x, $y))
    $result = $true
    while ($coordSt.Count -ne 0) {
        $c, $r = $coordSt.Pop()
        if (($f[$c, $r] -band $enemyMask) -ne 0 ) {
            $result = $false
            continue
        }
        if ($f[$c, $r] -ne $oldMark) {
            continue
        }
        $f[$c, $r] = $newMark
        $coordSt.Push(@(($c - 1), $r))
        $coordSt.Push(@(($c + 1), $r))
        $coordSt.Push(@($c, ($r - 1)))
        $coordSt.Push(@($c, ($r + 1)))
    }
    return $result
}

function pushTrackPointOrFillArea {
    param (
        [int[,]] $f,
        [Int] $x,
        [Int] $y,
        [Collections.Stack] $failSt,
        [Collections.Stack] $coordSt
    )

    if ($f[$x, $y] -eq 8) {
        $coordSt.Push(@($x, $y))
        return
    }

    if (($f[$x, $y] -band 17) -ne 0) {
        return
    }

    if (tryMark $f $x $y 2 0 32) {
        tryMark $f $x $y 0 32 24 | Out-Null
    } else {
        tryMark $f $x $y 0 32 16 | Out-Null
        $failSt.Push(@($x, $y))
    }
}

function clearFailedMarks {
    param (
        [int[,]] $f,
        [Collections.Stack] $failSt
    )

    while ($failSt.Count -ne 0) {
        $x, $y = $failSt.Pop()
        tryMark $f $x $y 0 16 0 | Out-Null
    }
}

function fillArea {
    param (
        [int[,]] $f,
        [Int] $x,
        [Int] $y
    )

    $failSt = [Collections.Stack]::new()
    $coordSt = [Collections.Stack]::new()
    $coordSt.Push(@($x, $y))
    while ($coordSt.Count -ne 0) {
        $c, $r = $coordSt.Pop()
        $f[$c, $r] = 24
        pushTrackPointOrFillArea $f ($c - 1) $r $failSt $coordSt
        pushTrackPointOrFillArea $f ($c + 1) $r $failSt $coordSt
        pushTrackPointOrFillArea $f $c ($r - 1) $failSt $coordSt
        pushTrackPointOrFillArea $f $c ($r + 1) $failSt $coordSt
    }
    clearFailedMarks $f $failSt
    return (paintTrack $f $x $y 1)
}

function takeStepPlayer {
    param (
        [int[,]] $f,
        [hashtable] $player
    )

    showCell $f $player.x $player.y
    $ox = $player.x
    $oy = $player.y
    $player.x += $player.dx
    $player.y += $player.dy
    $side = $f[$player.x, $player.y] -band 1
    if ($side -lt $player.side) {
        $player.oldx = $ox
        $player.oldy = $oy
    }
    if (($f[$player.x, $player.y] -band 14) -ne 0) {
        $player.x = $ox
        $player.y = $oy
        paintTrack $f $player.x $player.y 0 | Out-Null
        $player.dead = $true
        return -1
    }
    $painted = 0
    if ($side -gt $player.side) {
        $painted = fillArea $f $ox $oy
        $player.oldx = $player.x
        $player.oldy = $player.y
        setPlayerDirection $player 0 0 $true
    }
    $player.side = $side
    markCell $f $player
    showPlayer $f $player
    return $painted
}

function movePlayer {
    param (
        [int[,]] $f,
        [hashtable] $player
    )

    if ($player.dead) {
        return -1
    }

    if (isOutOfField $f ($player.x + $player.dx) ($player.y + $player.dy)) {
        setPlayerDirection $player 0 0 $true
        return 0
    }

    if (-not (isPlayerMoving $player)) {
        return 0
    }
    
    [Int] $painted = takeStepPlayer $f $player
    return $painted
}

function moveHeroes {
    param (
        [int[,]] $f,
        [hashtable] $player,
        [Collections.ArrayList] $actors
    )

    foreach ($actor in $actors) {
        moveActor $f $player $actor
        if ($player.dead) {
            return -1
        }
    }
    playerMustKeeoMoving $f $player $actors
    $result = movePlayer $f $player
    return $result
}

function isPlayerMoving {
    param (
        [hashtable] $player
    )

    return (($player.dx -ne 0) -or ($player.dy -ne 0))
}

function setPlayerDirection {
    param (
        [hashtable] $player,
        [int] $dx,
        [int] $dy,
        [bool] $mustStoreTimeStamp = $false
    )

    if ($mustStoreTimeStamp) {
        $player.idleTimeout = getIdleTimeout
    }

    $player.dx = $dx
    $player.dy = $dy
}

function continueControl {
    param (
        [hashtable] $state,
        [hashtable] $player
    )

    Start-Sleep -Milliseconds $state.delay

    if (-not ([Console]::KeyAvailable)) {
        return $true
    }

    $key = [Console]::ReadKey($true)

    switch ($key.Key) {
        { $_ -eq "Q" } { $state.lives = -1; return $false }
        { $_ -eq "P" } { [Console]::ReadKey($true) | Out-Null; break }
        { $_ -eq "Spacebar" } { setPlayerDirection $player 0 0 $true; break }
        { $_ -in "W", "UpArrow" } { setPlayerDirection $player 0 -1; break }
        { $_ -in "A", "LeftArrow" } { setPlayerDirection $player -1 0; break }
        { $_ -in "S", "DownArrow" } { setPlayerDirection $player 0 1; break }
        { $_ -in "D", "RightArrow" } { setPlayerDirection $player 1 0; break }
    }

    return $true
}

function gameOver {
    writeGreeting "Game over!"
    [Console]::ReadKey($true) | Out-Null
}

function newCounters {
    param (
        [int[,]] $f,
        [hashtable] $state
    )

    [hashtable] $counters = @{
        onePercent = 0 -as [Int];
        togo = 0 -as [Int];
        filled = 0 -as [Int];
        complete = 0 -as [Int]
    }

    $excluded = fillAndDrawBorders $f;
    $counters.onePercent = getOnePercentValue ($f.Length - $excluded)
    $counters.togo = getToGo $state.level $counters.onePercent
    return $counters
}

function applyChanges {
    param (
        [hashtable] $state,
        [hashtable] $counters,
        [Int] $changes
    )

    $counters.filled += $changes
    $state.score += 1 + [Math]::Truncate($changes / $counters.onePercent)
    $counters.complete = [Math]::Truncate($counters.filled * 100 / $counters.togo)
}

function isLevelComplete {
    param (
        [hashtable] $counters
    )

    return $counters.filled -ge $counters.togo
}

function nextLevel {
    param (
        [hashtable] $state,
        [hashtable] $counters
    )

    if ($counters.complete -gt 110) {
        $state.lives += [Math]::Truncate(($counters.complete - 100) / 10)
        writeTitle $state $counters.complete
    }

    if ($state.delay -gt 0) {
        $state.delay--
    }
    writeGreeting "Level complete."
    [Console]::ReadKey($true) | Out-Null
    $state.level++
}

function playLevel {
    param (
        [hashtable] $state,
        [hashtable] $geo
    )

    [int[,]] $f = [int[,]]::new($geo.width - 1, $geo.height - 1)
    [hashtable] $counters = newCounters $f $state
    [Collections.ArrayList] $actors = setActors $f $state.level
    [hashtable] $player = setPlayer $f
    [Int] $changes = 0
    
    writeTitle $state $counters.complete
    while (continueControl $state $player) {
        $changes = moveHeroes $f $player $actors
        if (isGeometryChanged $geo) {
            $state.lives = -1
            break
        }
        if ($changes -lt 0) {
            $state.lives--
            if ($state.lives -ge 0) {
                revivePlayer $f $player
            } else {
                gameOver
                break
            }
            writeTitle $state $counters.complete
        } 
        if ($changes -gt 0) {
            applyChanges $state $counters $changes
            writeTitle $state $counters.complete
            if (isLevelComplete $counters) {
                nextLevel $state $counters
                break
            }
        }
    }
}

function newState {
    param (
        [Int] $hi
    )

    return @{ hi = $hi; score = 0 -as [Int]; 
            level = 1 -as [Int]; lives = 9 -as [Int]; 
            delay = 20 -as [Int]}
}

function playRound {
    param (
        [Int] $hi
    )

    [hashtable] $state = newState $hi
    [hashtable] $geo = getGeometry
    while ($state.lives -ge 0) {
        clearConsole
        playLevel $state $geo
    }
    clearConsole
    return $state.score
}

function game {
    [String] $hiFileName = "xonips.xml"

    [Int] $hi = restoreHiScore $hiFileName
    [Int] $score = 0
    [hashtable] $consolestate = prepareConsole

    
    while (tryagain $hi $score) {
        $hi = registerScore $hi $score
        $score = playRound $hi
    }
    
    $hi = registerScore $hi $score
    restoreConsole $consolestate
    saveHiScore $hiFileName $hi
}

game
