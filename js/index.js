language = 'en'

const includeTranslation = (personalizedAttribute) => {
    const domPlaces = document.querySelectorAll(`[${personalizedAttribute}]`)
    domPlaces.forEach(place => {
        place.outerHTML = eval(`languageDictionary.${language}[personalizedAttribute]`)
    })
}

function parseURLParams(url) {
    const queryStart = url.indexOf("?") + 1,
        queryEnd = url.indexOf("#") + 1 || url.length + 1,
        query = url.slice(queryStart, queryEnd - 1),
        pairs = query.replace(/\+/g, " ").split("&")

    let parms = {}, i, n, v, nv

    if (query === url || query === "") return

    for (i = 0; i < pairs.length; i++) {
        nv = pairs[i].split("=", 2)
        n = decodeURIComponent(nv[0])
        v = decodeURIComponent(nv[1])

        if (!parms.hasOwnProperty(n)) parms[n] = []
        parms[n].push(nv.length === 2 ? v : null)
    }
    return parms
}


const documentReady = () => {
    const keys = Object.keys(languageDictionary.en)
    const currentLocation = location.toString()
    if (currentLocation.indexOf('?') >= 0) {
        const urlParams = parseURLParams(currentLocation)
        if (Object.keys(urlParams).includes('language')) {
            language = urlParams.language
        }
    }
    keys.map(includeTranslation)
}

if (document.readyState !== 'loading') {
    documentReady();
} else {
    document.addEventListener('DOMContentLoaded', documentReady);
}