GLOBAL_DATUM(the_gateway, /obj/machinery/gateway/centerstation)

/obj/machinery/gateway
	name = "gateway"
	desc = "Tajemnicza brama łącząca światy, zbudowana przed wiekami przez nieznane ręce. Wydaje ci się że po drugiej stronie czeka cię coś złowrogiego."
	icon = 'icons/obj/machines/gateway.dmi'
	icon_state = "off"
	density = TRUE
	resistance_flags = INDESTRUCTIBLE | LAVA_PROOF | FIRE_PROOF | UNACIDABLE | ACID_PROOF
	var/active = 0
	var/checkparts = TRUE
	var/list/obj/effect/landmark/randomspawns = list()
	var/calibrated = TRUE
	var/list/linked = list()
	var/can_link = FALSE	//Is this the centerpiece?

/obj/machinery/gateway/Initialize()
	randomspawns = GLOB.awaydestinations
	update_icon()
	if(!istype(src, /obj/machinery/gateway/centerstation) && !istype(src, /obj/machinery/gateway/centeraway))
		switch(dir)
			if(SOUTH,SOUTHEAST,SOUTHWEST)
				density = FALSE
	return ..()

/obj/machinery/gateway/proc/toggleoff()
	for(var/obj/machinery/gateway/G in linked)
		G.active = 0
		G.update_icon()
	active = 0
	update_icon()

/obj/machinery/gateway/proc/detect()
	if(!can_link)
		return FALSE
	linked = list()	//clear the list
	var/turf/T = loc
	var/ready = FALSE

	for(var/i in GLOB.alldirs)
		T = get_step(loc, i)
		var/obj/machinery/gateway/G = locate(/obj/machinery/gateway) in T
		if(G)
			linked.Add(G)
			continue

		//this is only done if we fail to find a part
		ready = FALSE
		toggleoff()
		break

	if((linked.len == 8) || !checkparts)
		ready = TRUE
	return ready

/obj/machinery/gateway/update_icon()
	if(active)
		icon_state = "on"
		return
	icon_state = "off"

/obj/machinery/gateway/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	if(!detect())
		return
	if(!active)
		toggleon(user)
		return
	toggleoff()

/obj/machinery/gateway/proc/toggleon(mob/user)
	return FALSE

/obj/machinery/gateway/safe_throw_at(atom/target, range, speed, mob/thrower, spin = TRUE, diagonals_first = FALSE, datum/callback/callback, force = MOVE_FORCE_STRONG)
	return

/obj/machinery/gateway/centerstation/Initialize()
	. = ..()
	if(!GLOB.the_gateway)
		GLOB.the_gateway = src
	update_icon()
	wait = world.time + CONFIG_GET(number/gateway_delay)	//+ thirty minutes default
	awaygate = locate(/obj/machinery/gateway/centeraway)

/obj/machinery/gateway/centerstation/Destroy()
	if(GLOB.the_gateway == src)
		GLOB.the_gateway = null
	return ..()

//this is da important part wot makes things go
/obj/machinery/gateway/centerstation
	density = TRUE
	icon_state = "offcenter"
	use_power = IDLE_POWER_USE

	//warping vars
	var/wait = 0				//this just grabs world.time at world start
	var/obj/machinery/gateway/centeraway/awaygate = null
	can_link = TRUE

/obj/machinery/gateway/centerstation/update_icon()
	if(active)
		icon_state = "oncenter"
		return
	icon_state = "offcenter"

/obj/machinery/gateway/centerstation/process()
	if((stat & (NOPOWER)) && use_power)
		if(active)
			toggleoff()
		return

	if(active)
		use_power(5000)

/obj/machinery/gateway/centerstation/toggleon(mob/user)
	if(!detect())
		return
	if(!powered())
		return
	if(!awaygate)
		to_chat(user, "<span class='notice'>Błąd: Nie znaleziono destynacji.</span>")
		return
	if(world.time < wait)
		to_chat(user, "<span class='notice'>Błąd: Triangulacja przestrzeni zagiętej wciąż trwa. Szacowany czas do zakończenia: [DisplayTimeText(wait - world.time)].</span>")
		return

	for(var/obj/machinery/gateway/G in linked)
		G.active = 1
		G.update_icon()
	active = 1
	update_icon()

//okay, here's the good teleporting stuff
/obj/machinery/gateway/centerstation/Bumped(atom/movable/AM)
	if(!active)
		return
	if(!detect())
		return
	if(!awaygate || QDELETED(awaygate))
		return

	if(awaygate.calibrated)
		AM.forceMove(get_step(awaygate.loc, SOUTH))
		AM.setDir(SOUTH)
		if (ismob(AM))
			var/mob/M = AM
			if (M.client)
				M.client.move_delay = max(world.time + 5, M.client.move_delay)
		return
	else
		var/obj/effect/landmark/dest = pick(randomspawns)
		if(dest)
			AM.forceMove(get_turf(dest))
			AM.setDir(SOUTH)
			use_power(5000)
		return

/obj/machinery/gateway/centeraway/multitool_act(mob/living/user, obj/item/I)
	if(calibrated)
		to_chat(user, "\black Brama już jest skalibrowana, nie masz co tu robić.")
	else
		to_chat(user, "<span class='boldnotice'>Rekalibracja zakończona powodzeniem!</span>: \black Systemy tej Bramy zostały dobrze nastawione.  Podróż do tej bramy będzie teraz celem.")
		calibrated = TRUE
	return TRUE

/////////////////////////////////////Away////////////////////////


/obj/machinery/gateway/centeraway
	density = TRUE
	icon_state = "offcenter"
	use_power = NO_POWER_USE
	var/obj/machinery/gateway/centerstation/stationgate = null
	can_link = TRUE


/obj/machinery/gateway/centeraway/Initialize()
	. = ..()
	update_icon()
	stationgate = locate(/obj/machinery/gateway/centerstation)


/obj/machinery/gateway/centeraway/update_icon()
	if(active)
		icon_state = "oncenter"
		return
	icon_state = "offcenter"

/obj/machinery/gateway/centeraway/toggleon(mob/user)
	if(!detect())
		return
	if(!stationgate)
		to_chat(user, "<span class='notice'>Błąd: Nie znaleziono destynacji podróży.</span>")
		return

	for(var/obj/machinery/gateway/G in linked)
		G.active = 1
		G.update_icon()
	active = 1
	update_icon()

/obj/machinery/gateway/centeraway/proc/check_exile_implant(mob/living/L)
	for(var/obj/item/implant/exile/E in L.implants)//Checking that there is an exile implant
		to_chat(L, "\black Brama na stacji wykryła twój implant wygnania, nie pozwala ci przejść.")
		return TRUE
	return FALSE

/obj/machinery/gateway/centeraway/Bumped(atom/movable/AM)
	if(!detect())
		return
	if(!active)
		return
	if(!stationgate || QDELETED(stationgate))
		return
	if(isliving(AM))
		if(check_exile_implant(AM))
			return
	else
		for(var/mob/living/L in AM.contents)
			if(check_exile_implant(L))
				say("Rejecting [AM]: Implant wygnania wykryty w zabezpieczonej formie życia.")
				return
	if(AM.has_buckled_mobs())
		for(var/mob/living/L in AM.buckled_mobs)
			if(check_exile_implant(L))
				say("Rejecting [AM]: Implant wygnania wykryty w pobliskiej formie życia.")
				return
	AM.forceMove(get_step(stationgate.loc, SOUTH))
	AM.setDir(SOUTH)
	if (ismob(AM))
		var/mob/M = AM
		if (M.client)
			M.client.move_delay = max(world.time + 5, M.client.move_delay)


/obj/machinery/gateway/centeraway/admin
	desc = "Tajemnicze wrota zbudowane przed wiekami, przez nieznane ręce, te wydają się być bardziej kompaktowe."

/obj/machinery/gateway/centeraway/admin/Initialize()
	. = ..()
	if(stationgate && !stationgate.awaygate)
		stationgate.awaygate = src

/obj/machinery/gateway/centeraway/admin/detect()
	return TRUE


/obj/item/paper/fluff/gateway
	info = "Congratulations,<br><br>Twoja stacja została wybrana aby uczestniczyć w projekcie 'gateway'!.<br><br>Materiały zostaną dostarczone do ciebie na początku następnego kwadransu.<br> Musisz przygotować zabezpieczone miejsce aby przechowywać materiały jak pokazano w załączonych dokumentach.<br><br>--Nanotrasen Bluespace Research"
	name = "Confidential Correspondence, Pg 1"

/obj/item/paper/fluff/itemnotice
	info = "Ogłoszenie: Przez następne parę tygodni będzie zwiększona ilość zgłoszeń nadmiaru śmieciowych przedmiotów, takich jak opakowania będą znajdywane w Produktach Bluespace'owych Kapsułek. Jeżeli znajdziemy się w posiadaniu takiego przedmiotu, prosimy o pozbycie się ich za pomocą koszów na śmieci lub zaopatrzonym ogniskiem, zwłaszcza jeżeli przedmioty upokorzające. Przepraszamy za nieporozumienie. Dziękujemy. -- Nanotrasen BS Productions"
	name = "Surplus Item Removal Notice"

/obj/item/paper/fluff/encampmentwelcome
	info = "Witaj! Jeżeli to czytasz, to kupiłeś i użyłeś nowej linii bluespace'owych kapsułek schronienia, górniczego obozu! Ta kapsułka zapewnia wszystko co zwykły model, i nawet więcej, jak rozszerzony wendomat z jedzeniem, sejf w podłodze, łazienki, przechowywanie ubrania, zapasowe wyposarzenie, oraz wendomat osobistych rekwizycji! Zewnętrze zostało udekorowane bazaltowym podłożem, aby żadne kamienie nie wlazły do przytulnego obozowiska! Mamy nadzieje że będziesz bezpieczny, i twój pobyt wśrodku będzie jak małe wakacje! - Nanotrasen BS Productions"
	name = "Witaj!"

/obj/item/paper/fluff/shuttlenotice
	info = "Do teraźniejszego kapitana stacji Nanotrens SS13, Poprzez naturę waszego problemu, niestety musimy odmówić konstrukcji promu ratunkowego, ponieważ nie spełnia on wymogów sanitarnych. Dziękujemy za zakup, i przepraszamy za nieporozumienie. Dziękujemy, i życzymy bezpiecznego lotu! -- Nanotrasen BS Productions Engineering Team"
	name = "Shuttle Notice"
