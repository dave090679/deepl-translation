function get-DeepLtranslation {
    <#
	.Synopsis
	Übersetzt einen Text in eine andere Sprache
	
	.Description
	Dieses Cmdlet verwendet den Übersetzungsdienst http://www.deepl.com/translator, um einen übergebenen text von einer in eine andere Sprache zu übertragen. Der zu übersetzende Text kann dabei wahlweise über die Pipeline, über einen unbenannten Parameter oder über den Parameter -sentence übergeben werden. 
	.parameter fromlang
	Dieser Parameter ist optional und gibt die Ausgangssprache an. Standard ist "auto". Damit wird deepl angewiesen, die Ausgangssprache automatisch zu erkennen.
	
	Folgende Werte sind zulässig:
	PL = polnisch
	EN = englisch
	DE = deutsch
	FR = französisch
	IT = italientisch
	NL = niederländisch
	auto = automatische Erkennung
	
	.parameter tolang
	Dieser Parameter legt die Zielsprache für die Übersetzung fest. Standardwert ist die im System eingestellte Sprache. Die hier zulässigen Sprachenangaben entsprechen denen beim parameter fromlang.
	
	.parameter text
	Dies ist der einzige Pflichtparameter. Er gibt den zu übersetzenden Text an. Dieser Parameter kann auch unbenannt übergeben werden (siehe Beispiele unten).
	.parameter select
	Dieser Parameter ist optional und kann verwendet werden, um eine bestimmte Übersetzung auszuwählen.
	.example
	Das folgende Beispiel übersetzt einen Text unter Verwendung der automatischen Sprachnerkennung von Deepl in die im System eingestellte Sprache und gibt die Übersetzung auf den Bildschirm aus:
	PS C:\> get-DeepLtranslation "this is a first test using Powershell."
	Dies ist ein erster Test mit Powershell.
	dies ist ein erster Test mit Powershell.
	Das ist ein erster Test mit Powershell.
	Dies ist ein erster Test unter Verwendung von Powershell.
	PS C:\>

.example
Das folgende Beispiel zeigt, wie Sie die Pipeline verwenden können, um einen Text mit Deepl zu übersetzen:
PS C:\> echo "this is a second test using the Pipeline instead of an unnamed parameter." | get-DeepLtranslation
Dies ist ein zweiter Test, bei dem die Pipeline anstelle eines unbenannten Parameters verwendet wird.
Dies ist ein zweiter Test, der die Pipeline anstelle eines unbenannten Parameters verwendet.
Dies ist ein zweiter Test mit der Pipeline anstelle eines unbenannten Parameters.
Dies ist ein zweiter Test, bei dem die Pipeline anstelle eines nicht benannten Parameters verwendet wird.
PS C:\>

.example
Ein drittes Beispiel zeigt, wie sie benannte Parameter verwenden können, um die Übersetzung zu beeinflussen.
PS C:\> get-DeepLtranslation -fromLang EN -toLang FR -sentence "in this third example, named parameters are used to cont
rol the behaviour of deepl."
dans ce troisième exemple, les paramètres nommés sont utilisés pour contrôler le comportement de deepl.
dans ce troisième exemple, des paramètres nommés sont utilisés pour contrôler le comportement de deepl.
Dans ce troisième exemple, les paramètres nommés sont utilisés pour contrôler le comportement de deepl.
dans ce troisième exemple, les paramètres nommés sont utilisés pour contrôler le comportement de Deepl.
PS C:\>

	.link
	Der funktionskern dieses Cmdlets stammt aus folgendem Forumsbeitrag: https://psvmware.wordpress.com/2017/09/11/get-deepltranslation-translating-straight-from-your-powershell/
	
	.link
	Grundlegende Informationen über die Funktionsweise der JsonRPC-Api von Deepl wurden aus dem folgenden Beitrag gewonnen: https://stackoverflow.com/questions/45937616/using-deepl-api-to-translate-text
	
	#>
    [CmdletBinding ()] 
    param (
        [parameter (mandatory = $false,
            helpmessage = "Ausgangssprache für den zu übersetzenden Text, Standard ist 'auto' (optional)")]
        [string]
        [ValidateSet("auto", "PL", "EN", "NL", "ES", "IT", "FR", "DE")]
        $fromLang = "auto", 
        [parameter (mandatory = $false,
            helpmessage = "Zielsprache für die Übersetzung, standardmäßig wird die im System eingestellte Sprache verwendet (optional).")]
        [string]
        [ValidateSet("PL", "EN", "NL", "ES", "IT", "FR", "DE")]
        $toLang = $(get-culture).name.Substring(0, 2).toupper(),
        [parameter (mandatory = $false)]
        [Int32]
        [validatescript ( {$_ -ge 0})]
        $select,
        [Parameter (Mandatory = $True, position = 0, ValueFromPipeline = $true, valuefromremainingarguments = $True,
            helpmessage = "zu übersetzender Text (obligatorisch)")]
        [string]
        $text
    )

    process {
        #Languages available: PL,EN,NL,ES,IT,FR
        if ($fromlang -ne "auto")
        {$fromlang = $fromlang.toupper()}
        $tolang = $tolang.toupper()
        $regexp = [regex] ("([^\.!\?;]+[\.!\?;]*)")
        $textarray = $regexp.Split($text)
        $url = "https://www.deepl.com/jsonrpc"
        $call = '{"jsonrpc":"2.0","method":"LMT_handle_jobs","params":{"jobs":['
        $jobsarray = @()
        foreach ($sentence in $textarray) {
            if ($sentence -ne "") {
                $job = '{"kind":"default","raw_en_sentence":"' + $sentence + '"}'
                $jobsarray += $job
            }
        }
        $call += [system.String]::Join(", ", $jobsarray)
        $call += '],"lang":{"user_preferred_langs":["' + $fromlang + '", "' + $tolang + '"],"source_lang_user_selected":"' + $fromLang + '","target_lang":"' + $toLang + '"},"priority":-1},"id":15}'
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($call)
        $web = [System.Net.WebRequest]::Create($url)
        $web.Method = "POST"
        $web.ContentLength = $bytes.Length
        $web.ContentType = "application/x-www-form-urlencoded"
        $stream = $web.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.close()
        $reader = New-Object System.IO.Streamreader -ArgumentList $web.GetResponse().GetResponseStream()
        $translations = ($reader.ReadToEnd()|ConvertFrom-Json).result.translations
        $reader.Close()
        $beamscount = @()
        foreach ($t in $translations) {
            $beamscount += $t.beams.count
        }
        $obj = $beamscount | measure -minimum
        $min = $obj.minimum
        $answer = @()
        for ($a = 0; $a -le $min - 1; $a++) {
            $temparray = @()
            for ($b = 0; $b -le $translations.count - 1; $b++) {
                $temparray += $translations[$b].beams[$a].postprocessed_sentence
            }
            $answer += [string]$temparray
        }
        # $answer = $translations.beams | select -ExpandProperty 'postprocessed_sentence'
        if (($select -gt 0) -and ($select -lt $answer.count)) {
            $retval = $answer[$select - 1]
        }
        else {
            $retval = ""
            $a = 0
            $answer | % {
                $translation = ""
                $n = $a + 1
                $translation += $n.tostring() + ") " + $_ + "`n"
                $retval += $translation
                $a = $a + 1
            }
        }
        return $retval
    }
}
