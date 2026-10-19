@import <Foundation/Foundation.j>

/*
    The URL hash decides the screen:

        #/                          the course menu
        #/courses/<id>              a course, at its first unsolved problem
        #/courses/<id>/<problem>    a problem in a course
        #/revise/<id>[/<problem>]   the same, in revision mode
        #/me                        the learner's own page
        #/register                  registering an email and a passkey

    Anything else is the menu.
*/
function RouterParse(aHash)
{
    var parts = (aHash || "").replace(/^#\/?/, "").split("/").filter(function(p) { return p.length > 0; });

    if ((parts[0] === "courses" || parts[0] === "revise") && parts.length >= 2 && parts.length <= 3)
        return { screen: "course", courseId: decodeURIComponent(parts[1]),
                 problemId: parts[2] ? decodeURIComponent(parts[2]) : nil,
                 revision: parts[0] === "revise" };

    if (parts.length === 1 && (parts[0] === "me" || parts[0] === "register"))
        return { screen: parts[0] };

    return { screen: "menu" };
}

function RouterCoursePath(aCourseId, aProblemId, isRevision)
{
    return (isRevision ? "#/revise/" : "#/courses/") + encodeURIComponent(aCourseId) +
           (aProblemId ? "/" + encodeURIComponent(aProblemId) : "");
}
