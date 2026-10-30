#include <adv3.h>
#include <en_us.h>

versionInfo: GameID
    name = 'adv3 Stabilization Regression'
    byline = 'by the skill regression fixture'
    htmlByline = 'by the skill regression fixture'
    version = '1'
    authorEmail = 'nobody@example.invalid'
    desc = 'A neutral fixture for manifest paths, actions, doors, and scope.'
;

gameMain: GameMainDef
    initialPlayerChar = me
    showIntro() { "Neutral stabilization fixture. [REGRESSION intro] "; }
;

workshop: Room 'Relay Workshop'
    "A compact generator stands beside a release panel. A sealed door leads
    north. [REGRESSION room=workshop] "
    north = workshopDoor
;

me: Actor
    location = workshop
;

releasePanel: Fixture 'gray release panel' 'release panel' @workshop
    "The panel carries a single release button. "
;

+ releaseButton: Button 'square release button' 'release button'
    dobjFor(Push)
    {
        action()
        {
            workshopDoor.isLocked = nil;
            archiveDoor.isLocked = nil;
            "Both lock bolts retract. [REGRESSION puzzle=unlocked-both] ";
        }
    }
;

testGenerator: Fixture 'compact test generator/machine' 'generator' @workshop
    "The generator is <<isOn ? 'running' : 'idle'>>.
    [REGRESSION generator-location=workshop state=<<isOn ? 'on' : 'off'>>] "
    isOn = nil

    dobjFor(TurnOn)
    {
        verify() { logical; }
        check()
        {
            if (isOn)
                failCheck('The generator is already running. ');
        }
        action()
        {
            isOn = true;
            "The generator starts. [REGRESSION action=TurnOn reached] ";
        }
    }
;

workshopDoor: LockableWithKey, Door
    'sealed north steel archive door' 'sealed door' @workshop
    "The workshop-side bolt is <<isLocked ? 'engaged' : 'released'>>. "
    otherSide = archiveDoor
    isLocked = true
    initiallyOpen = nil
;

archive: Room 'Records Annex'
    "Shelves line the annex. The paired door returns south.
    [REGRESSION room=archive] "
    south = archiveDoor
;

archiveDoor: LockableWithKey, Door
    'sealed south steel workshop door' 'sealed door' @archive
    "The annex-side bolt is <<isLocked ? 'engaged' : 'released'>>. "
    otherSide = workshopDoor
    isLocked = true
    initiallyOpen = nil
;

DefineIAction(RegressionStatus)
    execAction()
    {
        "[REGRESSION status location=<<gPlayerChar.location == workshop
            ? 'workshop' : 'archive'>> outer=<<workshopDoor.isLocked
            ? 'locked' : 'unlocked'>> inner=<<archiveDoor.isLocked
            ? 'locked' : 'unlocked'>> generator=<<testGenerator.isOn
            ? 'on' : 'off'>>] ";
    }
    actionTime = 0
;

VerbRule(RegressionStatus)
    'regressionstatus'
    : RegressionStatusAction
    verbPhrase = 'report/reporting regression status'
;

#ifdef __DEBUG
DefineIAction(RegressionArchiveSide)
    execAction()
    {
        gPlayerChar.moveInto(archive);
        "[REGRESSION debug-position=archive] ";
    }
    actionTime = 0
;

VerbRule(RegressionArchiveSide)
    'regressionarchiveside'
    : RegressionArchiveSideAction
    verbPhrase = 'position/positioning on the archive side'
;
#endif
