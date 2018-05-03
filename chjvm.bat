@echo off
setlocal enabledelayedexpansion
REM Fichier enregistré en UTF8
REM Sauvegarder la page des codes d'affichage actuelle
REM Et charger la page de codes d'affichage UTF8
for /f "tokens=1,2 delims=:" %%a in ('chcp') do set "old.cp=%%b"
set "old.cp=%old.cp: =%"
chcp 65001 > nul
REM Textes
set shell.name=%0%
set shell.name=%shell.name:.bat=%
set shell.version=1.7
REM 
REM Auteur : Naeregwen
REM Version beta.1.7 : 17/11/2017
REM
set shell.short.desc=Changeur de JVM
set shell.long.desc=Ce script sert à changer de JVM, dans une installation multi JVM
REM
set shell.cmd.line=%shell.name% [-?^|h] [-l] [-s] [-q] [-n user.jvm.number] [-d user.jvm.drive] [-r user.jvm.root]
REM 
set help.line.01#break=Un élément de la ligne de commande noté entre [crochets] est optionel
set help.line.02=-h^|? : Affichage de ce texte d'aide et quitter le script.
set help.line.03=-l   : Afficher une liste des JVM disponibles avec la configuration et quitter le script.
set help.line.04=-s   : Si mode non interactif, alors ne pas afficher de messages (sauf les erreurs).
set help.line.05=-q   : Si mode non interactif, alors n'afficher que le message final : la nouvelle version de java (sauf les erreurs).
set help.line.06=-n   : user.jvm.number = numéro de la JVM à sélectionner dans la liste. Mode non interactif.
set help.line.07=-d   : user.jvm.drive = Lettre du disque d'installation.
set help.line.08=-r   : user.jvm.root = Nom absolu du répertoire racine des JVM, sans mention du disque.
REM
set help.line.09#break=Exemple : Si le répertoire racine des JVM est C:\Outils_Dev\JAVA\
set help.line.10=Alors l'argument user.jvm.root aura pour valeur Outils_Dev\JAVA
REM
set help.line.11#break=Exemple de structure de répertoire multi JVM attendue :
set help.line.12=C:\Outils_Dev\JAVA\
set help.line.13=C:\Outils_Dev\JAVA\jdk1.6.0_45
set help.line.14=C:\Outils_Dev\JAVA\jdk1.7.0_80
set help.line.15=C:\Outils_Dev\JAVA\jdk1.8.0_144
set help.line.16=C:\Outils_Dev\JAVA\jre1.8.0_144
set help.line.17=C:\Outils_Dev\JAVA\Shell
REM
set help.line.18#break=Toutes les JVM doivent être installées dans un même répertoire de base 
set help.line.19=Et le nom de leur propre répertoire de base doit commencer par la lettre j.
set help.line.20=La lettre j est importante, parce qu'elle va être utilisée en tant que
set help.line.21=pivot du motif de recherche, pour retrouver toutes les JVM disponibles
REM
:setup
REM DEBUG
set "debug=0"
REM disk donne le disque contenant les installations de JVM
REM Elle doit se terminer par :
set "disk.default=C:"
set "disk=%disk.default%"
REM jvm.root donne le répertoire racine des installations de JVM
REM c-à-d, toutes les JVM doivent être installées dans ce répertoire
REM Exemple de structure attendue :
REM C:\Outils_Dev\JAVA\
REM C:\Outils_Dev\JAVA\jdk1.6.0_45
REM C:\Outils_Dev\JAVA\jdk1.7.0_80
REM C:\Outils_Dev\JAVA\jdk1.8.0_144
REM C:\Outils_Dev\JAVA\jre1.8.0_144
set "jvm.root.default=%disk%\Outils_Dev\JAVA"
set "jvm.root=%jvm.root.default%"
REM jvm.root.shell donne le répertoire de stockage des outils shells multi JVM
REM C'est le répertoire où est censé se trouver ce script 
REM Exemple de structure attendue :
REM C:\Outils_Dev\JAVA\Shell
set "jvm.root.shell=%jvm.root%\Shell"

set warn.border=***********************************************************
set warn.line.1=* Changeur de JVM                                         *
set warn.line.2=* Pour arrêter ce script, appuyer sur Ctrl+c, Entrée ou 0 *
set warn.line.3=* Pour avoir de l'aide, utiliser le paramètre -h          *

:read.arguments
REM Si aucun argument n'est présent,
REM Alors vérifier le contexte d'exécution
REM Puis afficher d'un menu d'interaction
if [%1] == [] goto verify.execution.context
call :parse.arguments %*

REM Besoin d'aide ?
if [%h%] == [true] set "display.usage=1"
if [%?%] == [true] set "display.usage=1"
if [%l%] == [true] set "display.jvm.list=1"
if [%q%] == [true] (
	set "mode.silent=1"
	set "mode.quiet=1"
)
REM Afficher des messages ?
if [%s%] == [true] set "mode.silent=1"

REM Un nouveau nom de disque est-il indiqué ?
REM Normalisation à la première lettre puis ajout du : final
:read.user.jvm.disk
if [%d%] == [true] (
	echo Erreur : argument manquant, -d n'est pas suivi d'une lettre de disque 1>&2
) else (
	if not [%d%] == [] (
		set "user.jvm.disk=%d:~0,1%"
		call :to.upper.case user.jvm.disk
		call :is.upper.alpha !user.jvm.disk!
		if defined not.upper.alpha (
			echo Erreur : L'argument suivant -d (!user.jvm.disk!^) n'est pas alphabétique 1>&2
			set "not.upper.alpha="
			set "user.jvm.disk="
		) else (
			if exist !user.jvm.disk!:\NUL (
				if not defined mode.silent echo disk redéfini par l'utilisateur pour !user.jvm.disk!
				set "disk=!user.jvm.disk!:"
			) else (
				echo Erreur : L'argument suivant -d (!user.jvm.disk!^) ne correspond pas à un disque lisible 1>&2
			)
		)
	)
)

REM Un nouveau répertoire de base des JVM est-il indiqué ?
REM Normalisation par suppression des caractères slash (\)
REM suffixe et préfixe de l'argument qui seraient superflus
:read.user.jvm.root
set "user.jvm.dir=%r%"
set "user.jvm.dir=!user.jvm.dir: =!"
::if [%r%] == [true] (
if [%user.jvm.dir%] == [true] (
	echo Erreur : argument manquant, -r n'est pas suivi d'un chemin de répertoire 1>&2
) else (
	if not "%r" == "" (
		set "user.jvm.root=%r%"
 		if "!user.jvm.root:~0,1!" == "\" set "user.jvm.root=!user.jvm.root:~1!"
		if "!user.jvm.root:~-1!" == "\" set "user.jvm.root=!user.jvm.root:~0,-1!"
		if exist !disk!\!user.jvm.root!\NUL (
			if not defined mode.silent echo jvm.root redéfini par l'utilisateur pour !user.jvm.root! (!disk!\!user.jvm.root!^)
			set "jvm.root=!disk!\!user.jvm.root!"
		) else (
			echo Erreur : le chemin %disk%\!user.jvm.root! n'est pas un répertoire 1>&2
		)
	)
)

:read.user.jvm.number
REM Un numéro de position de JVM est-il indiqué ?
if [%n%] == [true] (
	echo Erreur : argument manquant, -n n'est pas suivi d'un nombre 1>&2
	set "user.jvm.number.invalid=1"
) else ( 
	if not [%n%] == [] (
		set "user.jvm.number=%n%"
		call :is.numeric !user.jvm.number!
		if defined not.numeric (
			echo Erreur : l'argument qui suit -n n'est pas numérique (Entier positif ou nul non signé^) 1>&2
			set "not.numeric="
			set "user.jvm.number.invalid=1"
		) else (
			if !user.jvm.number! EQU 0 (
				if not defined mode.silent (
					echo Ok, on s'appelle plus tard
					calc
				)
				goto exit
			) else (
				call :check.for.user.jvm.number
				if not defined user.jvm.number.valid set "user.jvm.number.invalid=1"
			)
		)
	)
)

:verify.execution.context
call :check.execution.context
if not defined execution.context.error goto start.script
if [%jvm.count%] NEQ [%java.home.bin.error%] goto start.script

if "%jvm.root%" == "%jvm.root.default%" goto error.no.jvm.root.default
echo Erreur : le contexte donne en argument ne permet pas l'exécution du script (Aucune JVM disponible) 1>&2

:try.with.jvm.root.default
if not defined mode.silent echo Essai avec la configuration par défaut : %jvm.root.default%
set "jvm.root=%jvm.root.default%"
if defined user.jvm.number (
	set "user.jvm.number.invalid="
	call :check.for.user.jvm.number
	if defined user.jvm.number.valid goto verify.default.execution.context
	set "user.jvm.number.invalid=1"
)

:verify.default.execution.context
set "execution.context.error="
call :check.execution.context

if not defined execution.context.error goto start.script
if %jvm.count% NEQ %java.home.bin.error% goto start.script

:error.no.jvm.root.default
echo Erreur : Le contexte par defaut du script ne permet pas son exécution (Aucune JVM disponible) 1>&2
goto exit

:start.script
if defined display.usage (
	call :display.usage
	goto exit
)
if defined user.jvm.number.invalid goto exit
if not defined user.jvm.number goto display.start.message
set "user.choice=%user.jvm.number%"
goto retrieve.user.java.home.choice

:display.start.message
if defined display.jvm.list goto exit
call :display.warn
call :display.java.version

:display.java.home.choices
echo.
set "user.choice="
set /a jvm.count=0
echo %jvm.count% : Quitter le changeur de JVM
for /d %%d in (%jvm.root%\j*) do (
	if exist %%d\bin\NUL (
		set /a jvm.count+=1
		echo !jvm.count! : La nouvelle JVM sera = %%d
	)
)

set /p user.choice="Changer pour quelle JVM ? Choisissez un chiffre entre 0 et %jvm.count% : "

if [%user.choice%] == [] goto exit
if %user.choice% EQU 0 goto exit
if %user.choice% LSS 0 goto display.java.home.choices
if %user.choice% GTR %jvm.count% goto display.java.home.choices

:retrieve.user.java.home.choice
set /a jvm.count=0
for /d %%d in (%jvm.root%\j*) do (
	if exist %%d\bin\NUL (
		set /a jvm.count+=1
		if !jvm.count! EQU %user.choice% (
			set "java.home=%%d"
			goto display.user.java.home.choice
		)
	)
)

:display.user.java.home.choice
if not defined mode.silent echo.
if not defined mode.silent echo Vous avez choisi : %java.home%

:set.java.home.bin
set "java.home.bin=%java.home%\bin"

:set.new.path
set "new.path=%path%"

:remove.dat.oracle.path
REM Répertoire utilisé par certaines installations de JVM par Oracle (8 et suivante)
set "new.path=%new.path:C:\ProgramData\Oracle\Java\javapath=%"

:remove.all.java.home.bin.path
for /d %%d in (%jvm.root%\j*) do call set "new.path=%%new.path:%%d\bin=%%"

if %debug% EQU 0 goto normalize.new.path
echo.
echo CLEANED %new.path%

:normalize.new.path
REM Supprimer toutes les occurences de double séparateur (;;) se trouvant dans new.path
set "new.path=%new.path:;;=;%"

if %debug% EQU 0 goto trim.end.new.path
echo.
echo NORMALIZED %new.path%

:trim.end.new.path
REM Supprimer l'éventuel séparateur de fin (;) se trouvant dans new.path
if not "%new.path:~-1%" == ";" goto add.java.home.bin.to.new.path
set "new.path=%new.path:~0,-1%"
if not "%new.path:~-1%" == ";" goto add.java.home.bin.to.new.path
echo Erreur : le path se termine par un ; 1>&2
goto exit

:add.java.home.bin.to.new.path
set "new.path=%new.path%;%java.home.bin%"

if %debug% EQU 0 goto set.path.and.java.home
echo.
echo NEW_PATH %new.path%

:set.path.and.java.home
if not defined mode.silent echo Mise a jour de PATH et JAVA_HOME
REM Syntaxe importante : les & collés (surtout pour path) 
endlocal& set PATH=%new.path%& set JAVA_HOME=%java.home%& set display.jvm.list=%display.jvm.list%& set jvm.root=%jvm.root%& set mode.silent=%mode.silent%& set mode.quiet=%mode.quiet%

:show.current.java.
if defined mode.quiet (
	call :display.java.version
) else (
	if not defined mode.silent call :display.java.version
)
goto exit

REM
REM Fonctions
REM

REM Recherche de l'existence du répertoire jvm.root
REM Les répertoires contenant des espaces demandent une syntaxe différente
:look.for.jvm.root
if not "%jvm.root: =%" == "%jvm.root%" goto look.for.jvm.root.spaces
if exist %jvm.root%\NUL goto found.jvm.root
:jvm.root.error
echo Erreur : le répertoire %jvm.root% n'existe pas 1>&2
set "jvm.root.missing=1"
goto found.jvm.root
:look.for.jvm.root.spaces
if not exist "%jvm.root%" goto jvm.root.error
:found.jvm.root
goto :eof

REM Recherche de l'existence du répertoire jvm.root.shell
:look.for.jvm.root.shell
if exist %jvm.root.shell%\NUL goto found.jvm.root.shell
echo Erreur : le répertoire %jvm.root.shell% n'existe pas 1>&2
set "jvm.root.shell.missing=1"
:found.jvm.root.shell
goto :eof

REM Vérifier que jvm.root contient au moins un sous répertoire commencant par j
:check.for.jvm.root.installations
set /a jvm.count=0
for /d %%d in (%jvm.root%\j*) do set /a jvm.count+=1
if %jvm.count% NEQ 0 goto found.jvm.root.installations
echo Erreur : Aucune installation de JVM disponible dans le répertoire %jvm.root% 1>&2
:found.jvm.root.installations
goto :eof

:check.for.user.jvm.number
set "user.jvm.number.valid="
set /a jvm.count=0
for /d %%d in (%jvm.root%\j*) do (
	if exist %%d\bin\NUL (
		set /a jvm.count+=1
		if !jvm.count! EQU !user.jvm.number! set "user.jvm.number.valid=1"
	)
)
if not defined user.jvm.number.valid (
	echo Erreur : le numéro de position suivant -n (%user.jvm.number%^) est supérieur au nombre de JVM disponibles dans %jvm.root% (%jvm.count%^) 1>&2
)
goto :eof
	
REM Vérifier que les sous répertoires de jvm.root commençant par j
REM contiennent bien un sous répertoire bin
:check.for.all.java.home.bin
:cls
set /a java.home.bin=0
set /a java.home.bin.error=0
for /d %%d in ("%jvm.root%\j*") do (
	set "java.home.bin.current=%%d"
	echo java.home.bin.current = !java.home.bin.current!
	set java.home.bin.current=%java.home.bin.current: =%
	echo java.home.bin.current = !java.home.bin.current!
	echo java.home.bin.current = %!java.home.bin.current!: =%
	if "%!java.home.bin.current!: =%" == "!java.home.bin.current!" (
		call :look.for.java.home.bin "%%d"
	) else (
		call :look.for.java.home.bin.spaces "%%d"
	)
)
set "java.home.bin.current="
goto :eof

:look.for.java.home.bin	
echo 1=%~1%
if exist %~1%\bin\NUL (
	set /a java.home.bin+=1
) else (
	if not defined mode.silent echo Attention ^^! Le répertoire !java.home.bin.current! ne contient pas de répertoire bin
	set /a java.home.bin.error+=1
)
:goto :eof

:look.for.java.home.bin.spaces	
echo 1=%~1!% espace
if exist "%~1%\bin\NUL" (
	set /a java.home.bin+=1
) else (
	if not defined mode.silent echo Attention ^^! Le répertoire !java.home.bin.current! ne contient pas de répertoire bin
	set /a java.home.bin.error+=1
)
goto :eof

REM Vérifier le contexte du script permet son exécution
:check.execution.context
:verify.jvm.root
call :look.for.jvm.root
if defined jvm.root.missing goto error.in.execution.context

:verify.jvm.root.shell
call :look.for.jvm.root.shell
if defined jvm.root.shell.missing goto error.in.execution.context

:verify.jvm.root.installations
call :check.for.jvm.root.installations
if %jvm.count% EQU 0 goto error.in.execution.context

:verify.jvm.root.bin.installations
call :check.for.all.java.home.bin
if %java.home.bin.error% EQU 0 goto check.execution.context.end

:error.in.execution.context
set /a execution.context.error=1
:check.execution.context.end
goto :eof

REM Convertir l'argument en minuscule
:to.lower.case
for %%i in ("A=a" "B=b" "C=c" "D=d" "E=e" "F=f" "G=g" "H=h" "I=i" "J=j" "K=k" "L=l" "M=m" "N=n" "O=o" "P=p" "Q=q" "R=r" "S=s" "T=t" "U=u" "V=v" "W=w" "X=x" "Y=y" "Z=z") do call set "%1=%%%1:%%~i%%"
goto :eof

REM Convertir l'argument en majuscule
:to.upper.case
for %%i in ("a=A" "b=B" "c=C" "d=D" "e=E" "f=F" "g=G" "h=H" "i=I" "j=J" "k=K" "l=L" "m=M" "n=N" "o=O" "p=P" "q=Q" "r=R" "s=S" "t=T" "u=U" "v=V" "w=W" "x=X" "y=Y" "z=Z") do call set "%1=%%%1:%%~i%%"
goto :eof

REM Convertir l'argument en Camel Case
:to.camel.case
for %%i in (" a= A" " b= B" " c= C" " d= D" " e= E" " f= F" " g= G" " h= H" " i= I" " j= J" " k= K" " l= L" " m= M" " n= N" " o= O" " p= P" " q= Q" " r= R" " s= S" " t= T" " u= U" " v= V" " w= W" " x= X" " y= Y" " z= Z") do call set "%1=%%%1:%%~i%%"
goto :eof

REM Vérifier que l'argument est composé uniquement de lettres majuscules
:is.upper.alpha
set "not.upper.alpha="&for /f "delims=ABCDEFGHIJKLMNOPQRSTUVWXYZ" %%i in ("%~1") do set "not.upper.alpha=%%i"
goto :eof

REM Vérifier que l'argument est composé uniquement de chiffres
:is.numeric
set "not.numeric="&for /f "delims=0123456789" %%i in ("%~1") do set "not.numeric=%%i"
goto :eof

REM Afficher un message d'avertissement, pour éviter les catastrophes
:display.warn
echo.
echo %warn.border%
for /f "tokens=3* delims=.=" %%a in ('set warn.line.') do echo %%b
echo %warn.border%
goto :eof

REM Affiche les informations de version de la JVM courante
:display.java.version
echo.
echo La version actuelle de Java est :
java -version
goto :eof

REM Afficher une description
REM - des fonctionnalités du script
REM - et de sa syntaxe d'utilisation
:display.usage
echo.
echo %shell.name% : %shell.short.desc% - version %shell.version%
echo %shell.long.desc%
echo.
echo Utilisation : !shell.cmd.line!
for /f "tokens=3* delims=.=" %%a in ('set help.line.') do (
	set "line.number=%%a"
	if not "!line.number:break=!" == "!line.number!" echo.
	echo %%b
)
goto :eof

:display.usage.more
REM for /f "tokens=*" %%a in ('@call :display.usage') do @set test=%%a 
REM @call :display.usage > %temp%\x.txt & set /p test="" <%temp%\x.txt
REM  more !test!
REM call :display.usage
REM goto :eof

:display.jvm.list
setlocal enabledelayedexpansion
echo.
echo Liste des JVM disponibles :
set /a jvm.count=0
for /d %%d in (%jvm.root%\j*) do (
	if exist %%d\bin\NUL (
		set /a jvm.count+=1
		echo !jvm.count! : %%d
	)
)
endlocal
goto :eof

REM Analyse des arguments du script
REM Seule la premère lettre de l'argument est prise en considération.
REM Création des arguments sous forme de variables d'environnement 
REM - ayant pour nom la première lettre de l'argument
REM - ayant la valeur :
REM      - true pour les arguments non suivi d'une valeur
REM        (immédiatement suivi d'un autre argument)
REM      - de l'argument suivant pour les autres
:parse.arguments
:start.parse.arguments
if "%~1%" == "" goto stop.parse.arguments
if "%~1" == "-" goto parse.argument.error 
set "argument.name=%~1"
set "argument.name=%argument.name:~1,2%"
set "argument.value=%~2"
REM Si la valeur qui suit commence par - 
REM Alors c'est un nouvel argument
if "%argument.value:~0,1%" == "-" (
	set "%argument.name%=true"
	shift & goto start.parse.arguments
)
if "%argument.value%" == "" (
	set "%argument.name%=true"
	shift & goto start.parse.arguments
)
set "%argument.name%=%~2"
REM Ignorer le premier et le second argument
REM Ils viennent d'être traités
shift & shift & goto start.parse.arguments
:parse.argument.error
echo Erreur : l'indicateur de paramètre (-) n'est pas suivi d'un argument 1>&2
shift & goto start.parse.arguments
:stop.parse.arguments
goto :eof

:exit
if defined display.jvm.list call :display.jvm.list
REM Supprimer les variables qui auraient survecu au endlocal
set "display.jvm.list="
set "jvm.root="
set "mode.silent="
set "mode.quiet="
REM Restaurer la page des codes d'affichage
chcp %old.cp% > NUL
goto :eof
