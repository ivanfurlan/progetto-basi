-- phpMyAdmin SQL Dump
-- version 4.6.6deb5
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jun 18, 2019 at 06:01 PM
-- Server version: 5.7.26-0ubuntu0.19.04.1
-- PHP Version: 7.2.19-0ubuntu0.19.04.1

SET FOREIGN_KEY_CHECKS=0;
SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `progettoBasi`
--

DELIMITER $$
--
-- Procedures
--
DROP PROCEDURE IF EXISTS `eliminaCorsa`$$
CREATE PROCEDURE `eliminaCorsa` (IN `linea` CHAR(5), IN `corsa_` INT)  NO SQL
BEGIN
	SELECT * FROM Orario WHERE Orario.linea=linea AND Orario.corsa=corsa_;

	DELETE FROM Orario WHERE Orario.linea=linea AND Orario.corsa=corsa_;

	UPDATE Orario SET Orario.corsa=Orario.corsa - 1 WHERE Orario.linea = linea AND Orario.corsa > corsa_;
END$$

DROP PROCEDURE IF EXISTS `mostraLinea`$$
CREATE PROCEDURE `mostraLinea` (IN `linea` CHAR(5))  BEGIN
	SELECT OO.linea, FF.*
	from(
	    SELECT F.id as idFermata, F.Paese, F.descrizione as FermaIn, sum(case when O.tipo = 'feriale' then 1 else 0 end) AS CorseFerialiGiornaliere, sum(case when O.tipo = 'prefestivo' then 1 else 0 end) AS CorsePrefestiveGiornaliere, sum(case when O.tipo = 'festivo' then 1 else 0 end) AS CorseFestiveGiornaliere 
	    FROM  Orario O, Fermata F
	    WHERE O.linea=linea AND O.id_fermata=F.id
	    GROUP BY idFermata, F.Paese, FermaIn
	    ) FF, Orario OO
	WHERE FF.idFermata=OO.id_fermata AND OO.corsa=1 AND OO.linea=linea
	ORDER BY OO.ora;
END$$

DROP PROCEDURE IF EXISTS `mostraOrariViaggio`$$
CREATE PROCEDURE `mostraOrariViaggio` (IN `idViaggio` INT)  NO SQL
BEGIN

	SELECT F.id as idFermata, F.Paese, F.descrizione as FermaIn, O.ora AS oraArrivo
	FROM  Orario O, Fermata F, Viaggio V
	WHERE V.id=idViaggio AND O.linea=V.linea AND O.id_fermata=F.id AND O.corsa=V.corsa
	ORDER BY O.ora;

END$$

DROP PROCEDURE IF EXISTS `nuovaCorsa`$$
CREATE PROCEDURE `nuovaCorsa` (IN `da_linea` CHAR(5), IN `new_ora` TIME, IN `new_tipo_giorno` VARCHAR(15))  BEGIN 

	DROP TABLE IF EXISTS `percorso`;

	CREATE TABLE `percorso` (
	  `linea` char(5) NOT NULL,
	  `corsa` int(11) NOT NULL,
	  `id_fermata` int(11) NOT NULL,
	  `ora` time NOT NULL,
	  `tipo` varchar(15) NOT NULL DEFAULT 'feriale'
	);

	SET @daVG = 1;
	INSERT INTO `percorso` SELECT * FROM `Orario` WHERE `linea` = da_linea AND `corsa`=@daVG ORDER BY `ora`; 
	SET @vg = (SELECT MAX(`corsa`) FROM `Orario` WHERE `linea`=da_linea) + 1;
	UPDATE `percorso` SET `corsa` = @vg;

	IF(new_tipo_giorno<>'') THEN
		UPDATE `percorso` SET `tipo` = new_tipo_giorno;
	END IF;
	SET @temp = (SELECT P.ora FROM percorso P ORDER BY P.ora LIMIT 1);

	IF (@temp < new_ora) THEN
		SET @dif = TIME_TO_SEC(TIMEDIFF(new_ora,@temp));
		UPDATE `percorso` SET `ora` = ADDTIME(`ora`,SEC_TO_TIME(@dif));
	ELSE
		SET @dif = TIME_TO_SEC(TIMEDIFF(@temp,new_ora));
		UPDATE `percorso` SET `ora` = ADDTIME(`ora`,SEC_TO_TIME(@dif));
	END IF;
	INSERT INTO `Orario` SELECT * FROM `percorso`;

	DROP TABLE `percorso`;
	SELECT O.*, F.Paese, F.descrizione FROM Orario O, Fermata F WHERE O.id_fermata = F.id AND O.linea=da_linea AND O.corsa=@vg ORDER BY O.ora;

END$$

DROP PROCEDURE IF EXISTS `tabellonePartenze`$$
CREATE PROCEDURE `tabellonePartenze` (IN `id_fermata` INT, IN `ora` TIME)  NO SQL
BEGIN
	SELECT O.linea, concat(F.Paese, ' - ', F.descrizione) AS Direzione, O.ora AS OraPassaggio, O.tipo AS Giorno 
	from Orario O, (
		SELECT O.linea, O.corsa, O.id_fermata 
		FROM Orario O  
		WHERE (O.linea, O.corsa, O.ora) in (
		    SELECT O.linea, O.corsa, MAX(O.ora) AS ora
		    FROM Orario O
		    GROUP BY O.linea, O.corsa)
		) L, Fermata F
	WHERE O.id_fermata=id_fermata AND O.ora>=ora AND O.linea = L.linea AND O.corsa = L.corsa AND L.id_fermata = F.id AND F.id <> id_fermata
	ORDER BY OraPassaggio,linea,Direzione;

END$$

--
-- Functions
--
DROP FUNCTION IF EXISTS `calcoloStipendioDipendente`$$
CREATE FUNCTION `calcoloStipendioDipendente` (`cf_dipendente` CHAR(16), `Mese` TINYINT UNSIGNED, `Anno` SMALLINT UNSIGNED) RETURNS DECIMAL(10,2) NO SQL
    DETERMINISTIC
BEGIN

	DECLARE mes TINYINT;
	DECLARE ann SMALLINT;
	DECLARE stipendio DECIMAL(10,2);

	IF(Mese>0 AND Anno>1900) THEN
		SET mes = Mese;
		SET ann =Anno;
	ELSE
		SET mes = MONTH(curdate() - interval 1 month);
		SET ann = YEAR(curdate() - interval 1 month);
	END IF;

	SET stipendio =0;

	Select D.costoOrario*oreMeseSolareDipendente(cf_dipendente, mes, ann) INTO stipendio
	FROM Dipendente D 
	WHERE D.CF=cf_dipendente;

	RETURN stipendio;
END$$

DROP FUNCTION IF EXISTS `oreMeseSolareDipendente`$$
CREATE FUNCTION `oreMeseSolareDipendente` (`cf_dipendente` CHAR(16), `Mese` TINYINT, `Anno` SMALLINT) RETURNS DECIMAL(10,2) NO SQL
    DETERMINISTIC
BEGIN

	DECLARE mes TINYINT;
	DECLARE ann SMALLINT;
	DECLARE ore DECIMAL(10,2);

	IF(Mese>0 AND Anno>1900) THEN
		SET mes = Mese;
		SET ann =Anno;
	ELSE
		SET mes = MONTH(CURRENT_DATE);
		SET ann = YEAR(CURRENT_DATE);
	END IF;

	SET ore =0;

	SELECT TIME_TO_SEC(SUM(TIMEDIFF(T.fine,T.inizio)))/3600 INTO ore
	FROM Turno T 
	WHERE T.cf_dipendente= cf_dipendente AND EXTRACT(MONTH FROM T.inizio) = mes AND EXTRACT(YEAR FROM T.inizio) = ann;

	RETURN ore;
END$$

DROP FUNCTION IF EXISTS `stazioneArrivoLinea`$$
CREATE FUNCTION `stazioneArrivoLinea` (`linea` CHAR(5)) RETURNS INT(11) NO SQL
    DETERMINISTIC
BEGIN

	DECLARE stazioneArrivo INT;
	DECLARE vg INT;

	SET stazioneArrivo = 0;

	SET vg = 1;

	SELECT O.id_fermata INTO stazioneArrivo 
	FROM Orario O 
	WHERE O.linea=linea AND O.corsa=vg
	ORDER BY O.ora DESC
	LIMIT 1;

	RETURN stazioneArrivo;
END$$

DROP FUNCTION IF EXISTS `stazionePartenzaLinea`$$
CREATE FUNCTION `stazionePartenzaLinea` (`linea` CHAR(5)) RETURNS INT(11) NO SQL
    DETERMINISTIC
BEGIN

	DECLARE stazionePartenza INT;
	DECLARE vg INT;

	SET stazionePartenza = 0;

	SET vg = 1;

	SELECT O.id_fermata INTO stazionePartenza 
	FROM Orario O 
	WHERE O.linea=linea AND O.corsa=vg
	ORDER BY O.ora ASC
	LIMIT 1;

	RETURN stazionePartenza;
END$$

DROP FUNCTION IF EXISTS `validitaBigliettoUrbano`$$
CREATE FUNCTION `validitaBigliettoUrbano` (`idBigliettoUrbano` INT) RETURNS TEXT CHARSET latin1 NO SQL
    DETERMINISTIC
BEGIN
	DECLARE scadenza DATETIME DEFAULT '1800-01-01 00:00:00';

	SELECT ADDTIME(IFNULL(B.ora_convalidato, CURRENT_TIMESTAMP),T.tempo) INTO scadenza FROM Biglietto B, Tariffa T WHERE B.id=idBigliettoUrbano AND B.nome_tariffa=T.nome AND T.nome LIKE 'U%';

	IF (scadenza <= CURRENT_TIMESTAMP) THEN
		RETURN false;
	ELSE
		RETURN true;
	END IF;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `Biglietto`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Biglietto`;
CREATE TABLE `Biglietto` (
  `id` int(11) NOT NULL,
  `tipologia` varchar(15) NOT NULL,
  `nome_tariffa` char(5) NOT NULL,
  `fermata_partenza` int(11) DEFAULT NULL,
  `fermata_arrivo` int(11) DEFAULT NULL,
  `ora_convalidato` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Biglietto`:
--   `fermata_arrivo`
--       `Fermata` -> `id`
--   `fermata_partenza`
--       `Fermata` -> `id`
--   `nome_tariffa`
--       `Tariffa` -> `nome`
--

--
-- Dumping data for table `Biglietto`
--

INSERT INTO `Biglietto` (`id`, `tipologia`, `nome_tariffa`, `fermata_partenza`, `fermata_arrivo`, `ora_convalidato`) VALUES
(1, 'Urbano', 'U75', NULL, NULL, '2018-12-26 10:00:31'),
(2, 'Extraurbano', 'E20', 14, 1, '2018-12-25 14:35:43'),
(3, 'Urbano', 'U180', NULL, NULL, '2018-12-28 11:28:32'),
(4, 'Extraurbano', 'E10', 1, 14, '2018-12-29 17:29:31'),
(5, 'Urbano', 'U75', NULL, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `Mezzo`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Mezzo`;
CREATE TABLE `Mezzo` (
  `matricola` int(11) NOT NULL,
  `tipo` varchar(15) NOT NULL DEFAULT 'Autobus',
  `marca` varchar(20) NOT NULL,
  `alimentazione` enum('Gasolio','Metano','Benzina','Elettrico','Benzina-Elettrico','Metano-Elettrico') NOT NULL,
  `anno` year(4) DEFAULT NULL,
  `posti_sedere` int(11) NOT NULL,
  `posti_sediaRotelle` int(11) NOT NULL,
  `lunghezza_veicolo_mt` decimal(4,2) NOT NULL,
  `larghezza_veicolo_mt` decimal(4,2) NOT NULL,
  `altezza_veicolo_mt` decimal(4,2) NOT NULL,
  `deposito` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Mezzo`:
--   `deposito`
--       `Deposito` -> `id`
--

--
-- Dumping data for table `Mezzo`
--

INSERT INTO `Mezzo` (`matricola`, `tipo`, `marca`, `alimentazione`, `anno`, `posti_sedere`, `posti_sediaRotelle`, `lunghezza_veicolo_mt`, `larghezza_veicolo_mt`, `altezza_veicolo_mt`, `deposito`) VALUES
(2, 'Autobus', 'Mercedes', 'Gasolio', 2007, 52, 0, '12.00', '2.55', '2.95', 2),
(3, 'Autobus', 'Mercedes', 'Metano', 2015, 35, 2, '12.00', '2.55', '2.95', 2),
(4, 'Autobus', 'Mercedes', 'Gasolio', 2016, 54, 0, '12.50', '2.55', '2.95', 2),
(5, 'Autobus', 'Mercedes', 'Gasolio', 2016, 54, 0, '12.50', '2.55', '2.95', 2),
(6, 'Autobus', 'Mercedes', 'Gasolio', 2016, 54, 0, '12.50', '2.55', '2.95', 2),
(7, 'Autobus', 'Mercedes', 'Gasolio', 2016, 54, 0, '12.50', '2.55', '2.95', 2),
(8, 'Autobus', 'Mercedes', 'Metano', 2015, 36, 1, '10.00', '2.55', '2.95', 2),
(9, 'Autobus', 'Mercedes', 'Metano', 2015, 36, 1, '10.00', '2.55', '2.95', 2),
(10, 'Autobus', 'Mercedes', 'Metano', 2015, 36, 1, '10.00', '2.55', '2.95', 2),
(11, 'Autobus', 'Mercedes', 'Gasolio', 2017, 70, 0, '14.00', '2.55', '2.95', 2),
(12, 'Autobus', 'Mercedes', 'Gasolio', 2017, 70, 0, '14.00', '2.55', '2.95', 2),
(13, 'Autobus', 'Mercedes', 'Gasolio', 1999, 26, 0, '8.00', '2.55', '2.95', 2),
(14, 'Autobus', 'Mercedes', 'Gasolio', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(15, 'Autobus', 'Mercedes', 'Gasolio', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(16, 'Autobus', 'Mercedes', 'Gasolio', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(17, 'Autobus', 'Mercedes', 'Gasolio', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(18, 'Autobus', 'Mercedes', 'Gasolio', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(19, 'Autobus', 'Mercedes', 'Gasolio', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(20, 'Autobus', 'Mercedes', 'Metano', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(21, 'Autobus', 'Mercedes', 'Metano', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(22, 'Autobus', 'Mercedes', 'Metano', 2008, 50, 0, '18.30', '2.55', '2.95', 2),
(23, 'Autobus', 'Menarini', 'Gasolio', 2002, 44, 0, '10.00', '2.55', '2.95', 2),
(24, 'Autobus', 'Menarini', 'Gasolio', 2002, 44, 0, '10.00', '2.55', '2.95', 2),
(25, 'Autobus', 'Menarini', 'Gasolio', 2002, 44, 0, '10.00', '2.55', '2.95', 2),
(26, 'Autobus', 'Menarini', 'Gasolio', 2002, 44, 0, '10.00', '2.55', '2.95', 2);

-- --------------------------------------------------------

--
-- Table structure for table `Deposito`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Deposito`;
CREATE TABLE `Deposito` (
  `id` int(11) NOT NULL,
  `paese` varchar(40) NOT NULL DEFAULT 'Padova',
  `indirizzo` varchar(50) NOT NULL,
  `parcheggi` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Deposito`:
--

--
-- Dumping data for table `Deposito`
--

INSERT INTO `Deposito` (`id`, `paese`, `indirizzo`, `parcheggi`) VALUES
(2, 'Padova', 'Stazione', 100);

-- --------------------------------------------------------

--
-- Stand-in structure for view `dettaglioViaggi`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `dettaglioViaggi`;
CREATE TABLE `dettaglioViaggi` (
`idViaggio` int(11)
,`giornoViaggio` date
,`tipoGiorno` enum('Feriale','Prefestivo','Festivo')
,`linea` char(5)
,`corsa` int(11)
,`idFermataPartenza` int(11)
,`PaesePartenza` varchar(30)
,`FermataPartenza` varchar(50)
,`OraPartenza` time
,`idFermataArrivo` int(11)
,`PaeseArrivo` varchar(30)
,`FermataArrivo` varchar(50)
,`OraArrivo` time
,`CFConducente` char(16)
,`NomeConducente` varchar(61)
,`MatricolaVeicolo` int(11)
,`Veicolo` varchar(15)
,`marcaVeicolo` varchar(20)
,`alimentazioneVeicolo` enum('Gasolio','Metano','Benzina','Elettrico','Benzina-Elettrico','Metano-Elettrico')
,`posti_sedere` int(11)
,`posti_sediaRotelle` int(11)
,`lunghezza_veicolo_mt` decimal(4,2)
,`larghezza_veicolo_mt` decimal(4,2)
,`altezza_veicolo_mt` decimal(4,2)
);

-- --------------------------------------------------------

--
-- Table structure for table `Dipendente`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Dipendente`;
CREATE TABLE `Dipendente` (
  `CF` char(16) NOT NULL,
  `Nome` varchar(30) NOT NULL,
  `Cognome` varchar(30) NOT NULL,
  `Data_Nascita` date DEFAULT NULL,
  `Sesso` enum('M','F') NOT NULL,
  `Ruolo` set('Conducente','Controllore','InfoPoint','Dipendente','Pulizie','Meccanico') NOT NULL DEFAULT 'Dipendente',
  `Telefono` varchar(14) DEFAULT NULL,
  `Email` varchar(100) DEFAULT NULL,
  `costoOrario` decimal(10,2) NOT NULL DEFAULT '7.00'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Dipendente`:
--

--
-- Dumping data for table `Dipendente`
--

INSERT INTO `Dipendente` (`CF`, `Nome`, `Cognome`, `Data_Nascita`, `Sesso`, `Ruolo`, `Telefono`, `Email`, `costoOrario`) VALUES
('BFLFJM66I04W249D', 'Giulietta', 'Mccarty', '1970-06-08', 'F', 'Dipendente', '1643100779299', 'In@eu.co.uk', '8.63'),
('BQSZTR37U74D393Z', 'Christian', 'Compton', '1976-05-04', 'F', 'Controllore,Dipendente', '1635011254299', 'vehicula@enimEtiamimperdiet.edu', '9.34'),
('BSLHQX14R65H194S', 'Alessandro', 'Hewitt', '1964-02-08', 'M', 'Conducente,Dipendente', '1634040727999', 'ipsum.nunc@afacilisisnon.net', '9.76'),
('CGCMJV97U36Z668G', 'Sofia', 'Chang', '1987-11-19', 'F', 'Dipendente', '1605081332999', 'convallis.ante@enimSednulla.net', '7.14'),
('CHCMXB33Z49B533G', 'Giuseppe', 'Rollins', '1982-09-16', 'F', 'Dipendente', '1638092226999', 'feugiat@pede.ca', '7.39'),
('CKMMFM43O93Q724L', 'Lara', 'Kennedy', '1963-12-29', 'F', 'InfoPoint,Dipendente', '1643082048099', 'tincidunt.congue.turpis@non.com', '7.91'),
('CZMXBX71W01O928M', 'Gianluca', 'Zimmerman', '1969-01-11', 'F', 'Dipendente', '1693060739099', 'ut@lacus.org', '7.03'),
('DHZHCZ25H80J556R', 'Nicola', 'Noel', '1964-06-14', 'F', 'Conducente,Dipendente', '1603071430899', 'luctus@natoque.net', '9.97'),
('DJDYWX02L59S899C', 'Cristian', 'Mosley', '1997-08-18', 'M', 'Conducente,Dipendente', '1663043063899', 'lectus.ante.dictum@Aliquamfringillacursus.edu', '7.07'),
('DJWDSL64T69L932C', 'Rebecca', 'Farmer', '1987-11-30', 'F', 'Dipendente', '1634021085499', 'tortor.at@vulputateeu.com', '7.60'),
('DLBFWL72B39R051J', 'Mario', 'Contreras', '1972-03-30', 'M', 'Dipendente', '1638111685299', 'orci.luctus@fermentum.net', '8.79'),
('DRKMNV02Y10K473W', 'Monica', 'Keith', '1989-10-05', 'F', 'Conducente,Dipendente', '1673120709899', 'eu@eratnonummy.net', '9.17'),
('DTDJLK49Z20L144Q', 'Leonardo', 'Pace', '1975-12-05', 'F', 'InfoPoint,Dipendente', '1625061696499', 'nostra.per.inceptos@leoMorbineque.com', '9.41'),
('FHFPYJ82V85V404G', 'Mirko', 'Cardenas', '1974-02-10', 'F', 'Controllore,Dipendente', '1656050536699', 'velit@nuncidenim.com', '7.38'),
('FQHFHP75D16A465Y', 'Lucia', 'Barton', '1976-08-14', 'F', 'Dipendente', '1672090441299', 'in.consequat.enim@sagittisplacerat.ca', '7.25'),
('FRLVNI98T09F770V', 'Ivan', 'Furlan', '1998-12-09', 'M', 'Conducente,Controllore,Dipendente', '+393402654831', NULL, '7.00'),
('FZHPNT19K29G042I', 'Lisa', 'Boone', '1996-08-10', 'M', 'InfoPoint,Dipendente', '1613071107499', 'risus@sagittisDuisgravida.co.uk', '9.54'),
('GGDQQD84Y69P174R', 'Davide', 'Oconnor', '1994-12-12', 'M', 'Dipendente', '1655011483399', 'id@tellusjusto.edu', '7.22'),
('GHDGJN35Z32D931B', 'Vanessa', 'Prince', '1987-05-05', 'F', 'Dipendente', '1623072114799', 'aliquet.lobortis@Proin.ca', '7.42'),
('GTNLGD37I20G923F', 'Erika', 'Tucker', '1976-10-08', 'F', 'Conducente,Dipendente', '1626062945999', 'enim.diam.vel@lobortistellus.co.uk', '7.59'),
('GYGHCP62V68U299H', 'Giuseppe', 'Livingston', '1980-08-23', 'M', 'InfoPoint,Dipendente', '1654100352099', 'Donec.at@magnisdis.org', '9.97'),
('GYZKNF08S46R864L', 'Erica', 'Joseph', '1961-03-29', 'F', 'Controllore,Dipendente', '1661102613499', 'Vivamus@massaInteger.edu', '8.68'),
('HRDWTQ25O35S842G', 'Emanuele', 'Pratt', '1992-08-19', 'M', 'Controllore,Dipendente', '1676091985299', 'Class@congueIn.net', '9.43'),
('JGXLJZ85R38P557V', 'Alessandro', 'Randolph', '1995-01-08', 'M', 'Conducente,Dipendente', '1623112408999', 'primis@pellentesque.ca', '7.63'),
('JJGBTR28D10P407F', 'Erika', 'Kirkland', '1987-10-31', 'F', 'Controllore,Dipendente', '1641021095799', 'Quisque.varius@etrutrumnon.org', '9.31'),
('JJMWYD47D43I569T', 'Mirko', 'Mcintyre', '1988-03-31', 'F', 'InfoPoint,Dipendente', '1663032250799', 'magna@Donecconsectetuermauris.ca', '7.98'),
('JSGXLG95W85K630Q', 'Alice', 'Carson', '1977-02-18', 'F', 'Controllore,Dipendente', '1678031532399', 'urna@ametornare.net', '9.62'),
('JWXBBF57H79C747F', 'Nicoletta', 'Salinas', '1969-04-15', 'M', 'Controllore,Dipendente', '1670061438099', 'at@arcuimperdietullamcorper.org', '7.34'),
('JXQXMD96K36A283H', 'Vincenzo', 'Hooper', '1970-08-12', 'M', 'Dipendente', '1674060373699', 'sit.amet@orciquislectus.co.uk', '7.98'),
('KCMVFZ46P18L447Y', 'Erica', 'Roberson', '1994-08-29', 'F', 'Controllore,Dipendente', '1672120237999', 'Curae@dolorsitamet.net', '8.28'),
('KLLXNH06L79O722F', 'Veronica', 'Bridges', '1986-08-20', 'M', 'Dipendente', '1673061323699', 'magna.Cras@sapien.edu', '7.20'),
('KVXPNX89K14N643E', 'Mirko', 'Cervantes', '1988-09-18', 'M', 'Dipendente', '1620110487599', 'ligula.Nullam.feugiat@tortor.org', '7.99'),
('LLHWQN43K06I332R', 'Cristiano', 'Compton', '1992-03-24', 'M', 'Conducente,Dipendente', '1622022774099', 'nibh.Quisque@arcuac.net', '7.36'),
('LVSBWV80J02K706X', 'Aurora', 'Lloyd', '1994-07-12', 'M', 'Dipendente', '1685011171499', 'cursus.luctus@etmagnisdis.org', '9.74'),
('LWNQLS99F01Q021D', 'Matilde', 'Salazar', '1969-01-09', 'F', 'Controllore,Dipendente', '1694031384299', 'ornare.lectus@anteNunc.org', '8.22'),
('LWVRGN63N14N018Q', 'Viola', 'Levy', '1984-08-10', 'M', 'Controllore,Dipendente', '1629052470699', 'ante.ipsum@penatibusetmagnis.ca', '9.13'),
('LXXNZX04E00T935U', 'Chiara', 'Green', '1960-04-30', 'F', 'InfoPoint,Dipendente', '1674050656799', 'dui.nec.urna@euismodurnaNullam.org', '8.05'),
('MGWYWX27X50W206S', 'Marta', 'Workman', '1972-07-28', 'M', 'Conducente,Dipendente', '1672042010799', 'nulla@elementumlorem.net', '7.46'),
('MSYTHK97Y94C460Y', 'Francesca', 'Bean', '1988-01-06', 'F', 'Conducente,Dipendente', '1669112875899', 'ullamcorper.eu@semsemper.net', '9.53'),
('MSZLWH11H16E244K', 'Giacomo', 'Vincent', '1967-01-17', 'F', 'InfoPoint,Dipendente', '1606092107399', 'hymenaeos@dolorvitae.edu', '7.33'),
('MVCFRN12V39J717S', 'Arianna', 'Melton', '1985-03-27', 'M', 'InfoPoint,Dipendente', '1674061926299', 'ac@ornareInfaucibus.co.uk', '8.41'),
('MVSDCH03I29B752V', 'Alessio', 'Sloan', '1997-02-19', 'M', 'Dipendente', '1662010243799', 'neque@mi.com', '8.21'),
('MYVFZP09L64P112W', 'Davide', 'Walsh', '1964-09-18', 'F', 'Dipendente', '1608121559799', 'sem.ut.dolor@risusNuncac.com', '8.22'),
('NLBNPH24Z12A286C', 'Valerio', 'Paul', '1970-10-27', 'F', 'Dipendente', '1644111610499', 'arcu.ac.orci@semmagna.com', '9.20'),
('NRQXMK82M61M546Q', 'Emanuele', 'Houston', '1970-04-12', 'M', 'Conducente,Dipendente', '1651082791399', 'diam@cubiliaCuraeDonec.ca', '8.88'),
('NWTFYM75A31G527I', 'Gabriele', 'Pickett', '1978-10-25', 'M', 'Conducente,Dipendente', '1697032741499', 'enim@Suspendissealiquet.org', '8.96'),
('PHNDGN61K80H624M', 'Jessica', 'Bridges', '1969-12-20', 'F', 'Controllore,Dipendente', '1645030110499', 'Quisque.tincidunt.pede@metussit.org', '7.66'),
('PMSZPJ02Y90L787G', 'Maria', 'Odonnell', '1970-02-17', 'F', 'InfoPoint,Dipendente', '1628031620499', 'quis.lectus@tinciduntpedeac.com', '9.62'),
('PSCWPB29K28H913M', 'Giorgio', 'Gibson', '1979-05-13', 'F', 'Controllore,Dipendente', '1630032766199', 'montes.nascetur@consectetueradipiscingelit.net', '9.82'),
('PWDWZH18Y45M612N', 'Jacopo', 'Joseph', '1993-04-02', 'F', 'Dipendente', '1641121763599', 'Ut.tincidunt.vehicula@sapienmolestieorci.ca', '8.05'),
('QFZDHF86A61B682O', 'Armando', 'Schneider', '1959-05-06', 'F', 'Controllore,Dipendente', '1677030469499', 'dictum@molestietellus.co.uk', '8.44'),
('QVKFHB79P99O350V', 'Vittoria', 'Pierce', '1972-03-18', 'M', 'InfoPoint,Dipendente', '1691120760399', 'In@Suspendissecommodo.org', '9.12'),
('RGRFNC88Y49Y278P', 'Beatrice', 'Cote', '1983-08-19', 'M', 'Dipendente', '1652090269299', 'egestas.Duis@musDonecdignissim.edu', '9.53'),
('RJHYPQ76L55G001I', 'Giorgia', 'Ball', '1973-04-12', 'M', 'Dipendente', '1614110630699', 'porta@Inatpede.co.uk', '9.46'),
('RJZNXQ33T51D140K', 'Antonio', 'Nash', '1981-04-28', 'F', 'Controllore,Dipendente', '1631092612799', 'nec.diam.Duis@Vestibulumaccumsan.co.uk', '9.02'),
('RKDTDD33K65G190H', 'Daniele', 'Baker', '1974-09-17', 'M', 'Conducente,Dipendente', '1626090274799', 'scelerisque.lorem@eratvitaerisus.edu', '7.98'),
('RSBXHC33Q09E026D', 'Tommaso', 'Fernandez', '1986-06-01', 'F', 'Dipendente', '1681032549599', 'tellus.Suspendisse@imperdietnon.com', '7.82'),
('RYPWFF45D20I794N', 'Gabriele', 'Galloway', '1986-02-24', 'M', 'Conducente,Dipendente', '1606100678599', 'vel.faucibus@sempererat.co.uk', '8.55'),
('SGHYNS46R49U523M', 'Nicolò', 'Hardy', '1976-05-03', 'M', 'InfoPoint,Dipendente', '1665092194599', 'luctus@eleifendCras.co.uk', '8.65'),
('SGWLBP43S78F385N', 'Cristian', 'Henry', '1996-11-25', 'F', 'InfoPoint,Dipendente', '1600031027399', 'tempor@mipedenonummy.org', '8.86'),
('SKWRHX17S38W592D', 'Alessio', 'Chandler', '1991-04-22', 'M', 'InfoPoint,Dipendente', '1611010922099', 'Ut.semper.pretium@auctornuncnulla.edu', '7.39'),
('SQBDZZ51J16K079T', 'Simona', 'Erickson', '1977-02-26', 'F', 'Conducente,Dipendente', '1679070832599', 'dis@Nullamscelerisque.org', '9.06'),
('SSBPPR10B02U598N', 'Paola', 'Calderon', '1978-07-30', 'M', 'Dipendente', '1602120169299', 'lorem.ipsum.sodales@hendrerit.net', '9.64'),
('TDLDDK70H78G847Z', 'Nicola', 'Weiss', '1988-10-15', 'F', 'Controllore,Dipendente', '1627100516499', 'facilisis.lorem.tristique@convalliserateget.org', '8.88'),
('THZNVZ03Z31E841C', 'Vittoria', 'Mills', '1967-09-19', 'M', 'Controllore,Dipendente', '1667030405099', 'ut.nulla@purusgravidasagittis.com', '9.09'),
('TKRBKH09S71I353M', 'Andrea', 'Owen', '1972-08-20', 'M', 'Conducente,Dipendente', '1692092429799', 'gravida.sagittis.Duis@dui.net', '7.65'),
('TLTKGG52I96T903R', 'Edoardo', 'Bender', '1997-07-06', 'F', 'Conducente,Dipendente', '1639072385999', 'Mauris@nunc.com', '8.63'),
('TQFJNZ47F38W734R', 'Cristiano', 'Suarez', '1996-11-07', 'F', 'Dipendente', '1628040304299', 'pede@felisullamcorperviverra.net', '9.73'),
('TSMMYS68K01B382B', 'Giorgio', 'Ross', '1966-10-14', 'M', 'Conducente,Dipendente', '1623101122299', 'Maecenas.mi.felis@sapienAenean.co.uk', '8.08'),
('TTPYJQ98I54E912I', 'Angela', 'Hurst', '1965-03-01', 'M', 'Dipendente', '1695030717799', 'aptent.taciti.sociosqu@elementum.net', '7.17'),
('TYMTRK85G75Y310S', 'Giulietta', 'Lott', '1980-12-29', 'F', 'Controllore,Dipendente', '1681011991399', 'non.cursus@Donecluctus.co.uk', '7.73'),
('VMFCHX88W06S353U', 'Fabio', 'Fitzpatrick', '1984-09-30', 'M', 'InfoPoint,Dipendente', '1669010316599', 'magnis@enimcommodo.co.uk', '8.78'),
('VRDGN77R10G224Z', 'Gianni', 'Verdi', '1977-10-10', 'M', 'Conducente,Dipendente', NULL, NULL, '8.00'),
('VSNJMB83M46Z599I', 'Giorgia', 'Solis', '1968-05-06', 'F', 'InfoPoint,Dipendente', '1603040525399', 'libero.Proin@lobortisnisi.ca', '7.90'),
('VWMXQP12F81R674V', 'Christian', 'Bailey', '1975-01-15', 'M', 'Controllore,Dipendente', '1628042504699', 'et.magna.Praesent@bibendumDonecfelis.org', '9.70'),
('VXHMHY10I06V405L', 'Margherita', 'Rose', '1978-11-07', 'F', 'InfoPoint,Dipendente', '1649113034199', 'erat.eget@scelerisquesed.ca', '7.73'),
('WFPDMT25G65U247G', 'Lara', 'Humphrey', '1963-07-24', 'F', 'Controllore,Dipendente', '1678081834099', 'sapien.molestie@nonmassa.edu', '8.57'),
('WHXZHR70D16J114W', 'Valerio', 'Joyce', '1989-02-14', 'M', 'Conducente,Dipendente', '1645031449799', 'dictum.mi.ac@atfringillapurus.ca', '7.04'),
('WPCCJG79E92B894O', 'Vittoria', 'Logan', '1958-10-03', 'F', 'Conducente,Dipendente', '1681051402299', 'dolor.dapibus@mifelisadipiscing.co.uk', '8.84'),
('WSQRST59U19W817S', 'Anna', 'Scott', '1958-11-21', 'F', 'InfoPoint,Dipendente', '1616072625599', 'sit@fermentummetusAenean.ca', '8.27'),
('WTFYSV73C11S161T', 'Cristiano', 'Hanson', '1997-04-16', 'M', 'InfoPoint,Dipendente', '1657060457999', 'vel.venenatis.vel@placeratCrasdictum.edu', '9.51'),
('WVFMHT29U90A549K', 'Gianluca', 'Pena', '1979-12-18', 'F', 'InfoPoint,Dipendente', '1688112616199', 'ante.bibendum@Duisrisusodio.net', '8.96'),
('WXGMWB44X13D576N', 'Pietro', 'Russell', '1996-02-12', 'F', 'InfoPoint,Dipendente', '1638020661699', 'lacus.Etiam@nonummyultriciesornare.edu', '7.61'),
('WZPDQK11Q79W433H', 'Marcello', 'Ewing', '1988-11-04', 'F', 'InfoPoint,Dipendente', '1662062979299', 'congue.a@Donecatarcu.com', '9.40'),
('XDJXFS05Z16K926A', 'Alessio', 'Dudley', '1978-10-14', 'M', 'Conducente,Dipendente', '1656050806099', 'lobortis.risus@loremlorem.net', '9.68'),
('XKYLBY44H25D195T', 'Filippo', 'Phelps', '1996-06-06', 'M', 'InfoPoint,Dipendente', '1680100484699', 'aliquam.adipiscing@sociisnatoque.co.uk', '7.70'),
('XNFPHR67Y41V883G', 'Manuel', 'Jordan', '1984-09-12', 'M', 'Dipendente', '1607112392799', 'egestas.Duis.ac@convallisconvallis.edu', '7.79'),
('XVKRDT04P12E714Y', 'Andrea', 'Jimenez', '1969-03-31', 'M', 'Controllore,Dipendente', '1616040813199', 'Vivamus.sit.amet@cursusnon.ca', '8.90'),
('XWDCBK41W44E310O', 'Alberto', 'Wyatt', '1984-02-24', 'F', 'Conducente,Dipendente', '1674050717799', 'Aenean.gravida@disparturientmontes.ca', '7.21'),
('XWSTTM56J28M378H', 'Simona', 'French', '1986-01-15', 'F', 'Dipendente', '1699092979299', 'sollicitudin.orci.sem@Maecenasliberoest.org', '7.75'),
('XXDPNW14D15S106S', 'Sofia', 'Hogan', '1960-11-12', 'M', 'Dipendente', '1693070733399', 'rhoncus.Donec.est@Vestibulumanteipsum.co.uk', '7.14'),
('YGLXPC37Y68I364F', 'Noemi', 'Cunningham', '1984-03-23', 'F', 'Dipendente', '1644021394299', 'aliquet.libero@mauris.edu', '8.53'),
('YHGKWK40F85D529K', 'Nicoletta', 'Long', '1976-08-26', 'F', 'Dipendente', '1676081229599', 'pede.Cum@Suspendissecommodo.net', '9.48'),
('YHNLSS11O61G790M', 'Davide', 'Moran', '1964-09-02', 'M', 'Dipendente', '1607051768199', 'montes.nascetur@eget.com', '7.30'),
('YNTNYN66D32V051S', 'Maria', 'Barrera', '1979-08-12', 'M', 'InfoPoint,Dipendente', '1688050588499', 'sit@musProin.edu', '7.72'),
('YYFKVY12M53E160G', 'Aurora', 'Faulkner', '1975-02-17', 'F', 'Controllore,Dipendente', '1658061092199', 'dapibus.ligula@nibhQuisquenonummy.com', '9.04'),
('ZFPRCZ79R67G492V', 'Samuel', 'Obrien', '1984-07-04', 'M', 'Dipendente', '1679090258299', 'sapien.gravida.non@turpisnec.org', '8.15'),
('ZGQWGV41L32D675B', 'Alessandra', 'Wilcox', '1967-05-11', 'F', 'InfoPoint,Dipendente', '1663093089299', 'Nam.ligula.elit@risusMorbi.ca', '8.12'),
('ZHMNLN13M20S235X', 'Caterina', 'Yates', '1961-03-24', 'M', 'Dipendente', '1663080321199', 'nec.eleifend@mollisnoncursus.net', '7.00'),
('ZKRFNG18C69D751L', 'Filippo', 'Mccoy', '1980-02-06', 'F', 'Dipendente', '1678050429899', 'nascetur.ridiculus.mus@liberoProinmi.com', '7.73'),
('ZQSVXF91O97S167I', 'Luigi', 'Vaughn', '1966-07-12', 'M', 'Dipendente', '1661022962699', 'vel@antedictum.edu', '7.05'),
('ZSXTHQ84C59S400O', 'Mario', 'Carrillo', '1991-10-16', 'M', 'Conducente,Dipendente', '1625092669999', 'est.mollis@ipsum.net', '7.07');

-- --------------------------------------------------------

--
-- Stand-in structure for view `dipendentiPerRuolo`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `dipendentiPerRuolo`;
CREATE TABLE `dipendentiPerRuolo` (
`Ruolo` set('Conducente','Controllore','InfoPoint','Dipendente','Pulizie','Meccanico')
,`numeroDipendenti` bigint(21)
);

-- --------------------------------------------------------

--
-- Table structure for table `Fermata`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Fermata`;
CREATE TABLE `Fermata` (
  `id` int(11) NOT NULL,
  `Paese` varchar(30) NOT NULL DEFAULT 'Padova',
  `descrizione` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Fermata`:
--

--
-- Dumping data for table `Fermata`
--

INSERT INTO `Fermata` (`id`, `Paese`, `descrizione`) VALUES
(1, 'Padova', 'Ferrovia'),
(2, 'Padova', 'Corso del Popolo'),
(3, 'Padova', 'Corso Garibaldi'),
(4, 'Padova', 'Riviera Ponti Romani'),
(5, 'Padova', 'Riviera Tito Livio'),
(6, 'Padova', 'Riviera Businello'),
(7, 'Padova', 'Prato della ValleVia Cavazzana'),
(8, 'Padova', 'Via Acquapendente'),
(9, 'Padova', 'Ponte 4 Martiri'),
(10, 'Padova', 'Salboro'),
(11, 'Padova', 'Pozzoveggiani'),
(12, 'Padova', 'S. Giacomo'),
(13, 'Padova', 'Lion di Albignasego'),
(14, 'Rovigo', 'Stazione'),
(15, 'Venezia', 'Mestre Stazione'),
(16, 'Venezia', 'Piazzale Roma');

-- --------------------------------------------------------

--
-- Stand-in structure for view `Linee`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `Linee`;
CREATE TABLE `Linee` (
`linea` char(5)
,`Descrizione` varchar(165)
,`idStazionePartenza` int(11)
,`stazionePartenza` varchar(81)
,`idStazioneArrivo` int(11)
,`stazioneArrivo` varchar(81)
);

-- --------------------------------------------------------

--
-- Table structure for table `Orario`
--
-- Creation: Jun 18, 2019 at 03:49 PM
-- Last update: Jul 09, 2019 at 07:56 PM
--

DROP TABLE IF EXISTS `Orario`;
CREATE TABLE `Orario` (
  `linea` char(5) NOT NULL,
  `corsa` int(11) NOT NULL,
  `id_fermata` int(11) NOT NULL,
  `ora` time NOT NULL,
  `tipo` enum('Feriale','Prefestivo','Festivo') NOT NULL DEFAULT 'Feriale'
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Orario`:
--   `id_fermata`
--       `Fermata` -> `id`
--

--
-- Dumping data for table `Orario`
--

INSERT INTO `Orario` (`linea`, `corsa`, `id_fermata`, `ora`, `tipo`) VALUES
('E99A', 1, 1, '07:30:00', 'Feriale'),
('E99A', 1, 14, '07:00:00', 'Feriale'),
('E99A', 1, 15, '08:00:00', 'Feriale'),
('E99A', 2, 1, '19:30:00', 'Feriale'),
('E99A', 2, 14, '19:00:00', 'Feriale'),
('E99A', 2, 15, '20:00:00', 'Feriale'),
('E99A', 3, 1, '07:30:00', 'Festivo'),
('E99A', 3, 14, '07:00:00', 'Festivo'),
('E99A', 3, 15, '08:00:00', 'Festivo'),
('E99A', 4, 1, '21:42:00', 'Feriale'),
('E99A', 4, 14, '21:12:00', 'Feriale'),
('E99A', 4, 15, '22:12:00', 'Feriale'),
('E99B', 1, 1, '07:30:00', 'Feriale'),
('E99B', 1, 14, '08:00:00', 'Feriale'),
('E99B', 1, 15, '07:00:00', 'Feriale'),
('E99C', 1, 1, '12:30:00', 'Prefestivo'),
('E99C', 1, 14, '12:00:00', 'Prefestivo'),
('E99C', 1, 15, '13:00:00', 'Prefestivo'),
('E99C', 1, 16, '13:15:00', 'Prefestivo'),
('E99D', 1, 1, '08:45:00', 'Festivo'),
('E99D', 1, 14, '09:15:00', 'Festivo'),
('E99D', 1, 15, '08:15:00', 'Festivo'),
('E99D', 1, 16, '08:00:00', 'Festivo'),
('E99D', 2, 1, '10:32:00', 'Prefestivo'),
('E99D', 2, 14, '11:02:00', 'Prefestivo'),
('E99D', 2, 15, '10:02:00', 'Prefestivo'),
('E99D', 2, 16, '09:47:00', 'Prefestivo'),
('U03A', 1, 1, '06:20:00', 'Feriale'),
('U03A', 1, 2, '06:21:00', 'Feriale'),
('U03A', 1, 3, '06:22:00', 'Feriale'),
('U03A', 1, 4, '06:24:00', 'Feriale'),
('U03A', 1, 5, '06:26:00', 'Feriale'),
('U03A', 1, 6, '06:28:00', 'Feriale'),
('U03A', 1, 7, '06:30:00', 'Feriale'),
('U03A', 1, 8, '06:32:00', 'Feriale'),
('U03A', 1, 9, '06:34:00', 'Feriale'),
('U03A', 1, 10, '06:36:00', 'Feriale'),
('U03A', 1, 11, '06:38:00', 'Feriale'),
('U03A', 1, 12, '06:40:00', 'Feriale'),
('U03A', 1, 13, '06:42:00', 'Feriale'),
('U03A', 2, 1, '06:30:00', 'Festivo'),
('U03A', 2, 2, '06:31:00', 'Festivo'),
('U03A', 2, 3, '06:32:00', 'Festivo'),
('U03A', 2, 4, '06:34:00', 'Festivo'),
('U03A', 2, 5, '06:36:00', 'Festivo'),
('U03A', 2, 6, '06:38:00', 'Festivo'),
('U03A', 2, 7, '06:40:00', 'Festivo'),
('U03A', 2, 8, '06:42:00', 'Festivo'),
('U03A', 2, 9, '06:44:00', 'Festivo'),
('U03A', 2, 10, '06:46:00', 'Festivo'),
('U03A', 2, 11, '06:48:00', 'Festivo'),
('U03A', 2, 12, '06:50:00', 'Festivo'),
('U03A', 2, 13, '06:52:00', 'Festivo'),
('U03A', 3, 1, '06:35:00', 'Feriale'),
('U03A', 3, 2, '06:36:00', 'Feriale'),
('U03A', 3, 3, '06:37:00', 'Feriale'),
('U03A', 3, 4, '06:39:00', 'Feriale'),
('U03A', 3, 5, '06:41:00', 'Feriale'),
('U03A', 3, 6, '06:43:00', 'Feriale'),
('U03A', 3, 7, '06:45:00', 'Feriale'),
('U03A', 3, 8, '06:47:00', 'Feriale'),
('U03A', 3, 9, '06:49:00', 'Feriale'),
('U03A', 3, 10, '06:51:00', 'Feriale'),
('U03A', 3, 11, '06:53:00', 'Feriale'),
('U03A', 3, 12, '06:55:00', 'Feriale'),
('U03A', 3, 13, '06:57:00', 'Feriale'),
('U03A', 4, 1, '06:40:00', 'Prefestivo'),
('U03A', 4, 2, '06:41:00', 'Prefestivo'),
('U03A', 4, 3, '06:42:00', 'Prefestivo'),
('U03A', 4, 4, '06:44:00', 'Prefestivo'),
('U03A', 4, 5, '06:46:00', 'Prefestivo'),
('U03A', 4, 6, '06:48:00', 'Prefestivo'),
('U03A', 4, 7, '06:50:00', 'Prefestivo'),
('U03A', 4, 8, '06:52:00', 'Prefestivo'),
('U03A', 4, 9, '06:54:00', 'Prefestivo'),
('U03A', 4, 10, '06:56:00', 'Prefestivo'),
('U03A', 4, 11, '06:58:00', 'Prefestivo'),
('U03A', 4, 12, '07:00:00', 'Prefestivo'),
('U03A', 4, 13, '07:02:00', 'Prefestivo'),
('U03A', 5, 1, '06:48:00', 'Feriale'),
('U03A', 5, 2, '06:49:00', 'Feriale'),
('U03A', 5, 3, '06:50:00', 'Feriale'),
('U03A', 5, 4, '06:52:00', 'Feriale'),
('U03A', 5, 5, '06:54:00', 'Feriale'),
('U03A', 5, 6, '06:56:00', 'Feriale'),
('U03A', 5, 7, '06:58:00', 'Feriale'),
('U03A', 5, 8, '07:00:00', 'Feriale'),
('U03A', 5, 9, '07:02:00', 'Feriale'),
('U03A', 5, 10, '07:04:00', 'Feriale'),
('U03A', 5, 11, '07:06:00', 'Feriale'),
('U03A', 5, 12, '07:08:00', 'Feriale'),
('U03A', 5, 13, '07:10:00', 'Feriale'),
('U03A', 6, 1, '19:15:00', 'Festivo'),
('U03A', 6, 2, '19:16:00', 'Festivo'),
('U03A', 6, 3, '19:17:00', 'Festivo'),
('U03A', 6, 4, '19:19:00', 'Festivo'),
('U03A', 6, 5, '19:21:00', 'Festivo'),
('U03A', 6, 6, '19:23:00', 'Festivo'),
('U03A', 6, 7, '19:25:00', 'Festivo'),
('U03A', 6, 8, '19:27:00', 'Festivo'),
('U03A', 6, 9, '19:29:00', 'Festivo'),
('U03A', 6, 10, '19:31:00', 'Festivo'),
('U03A', 6, 11, '19:33:00', 'Festivo'),
('U03A', 6, 12, '19:35:00', 'Festivo'),
('U03A', 6, 13, '19:37:00', 'Festivo');

-- --------------------------------------------------------

--
-- Stand-in structure for view `StipendiUltimoMese`
-- (See below for the actual view)
--
DROP VIEW IF EXISTS `StipendiUltimoMese`;
CREATE TABLE `StipendiUltimoMese` (
`CF` char(16)
,`Nome` varchar(61)
,`Ruolo` set('Conducente','Controllore','InfoPoint','Dipendente','Pulizie','Meccanico')
,`Mese` varchar(64)
,`costoOrario` decimal(10,2)
,`Ore` decimal(10,2)
,`Stipendio` decimal(10,2)
);

-- --------------------------------------------------------

--
-- Table structure for table `Tariffa`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Tariffa`;
CREATE TABLE `Tariffa` (
  `nome` char(5) NOT NULL,
  `classe_km` float DEFAULT NULL,
  `tempo` time DEFAULT NULL,
  `prezzo` float NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Tariffa`:
--

--
-- Dumping data for table `Tariffa`
--

INSERT INTO `Tariffa` (`nome`, `classe_km`, `tempo`, `prezzo`) VALUES
('E10', 10, NULL, 2),
('E100', 100, NULL, 22),
('E150', 150, NULL, 30),
('E20', 20, NULL, 3),
('E200', 200, NULL, 35),
('E30', 30, NULL, 9),
('E40', 40, NULL, 12),
('E50', 50, NULL, 15),
('E70', 70, NULL, 17),
('E80', 80, NULL, 19),
('E90', 90, NULL, 21),
('U180', NULL, '03:00:00', 3),
('U75', NULL, '01:15:00', 1.5);

-- --------------------------------------------------------

--
-- Table structure for table `Turno`
--
-- Creation: Jun 18, 2019 at 03:43 PM
--

DROP TABLE IF EXISTS `Turno`;
CREATE TABLE `Turno` (
  `id` int(11) NOT NULL,
  `cf_dipendente` char(16) NOT NULL,
  `inizio` datetime NOT NULL,
  `fine` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Turno`:
--   `cf_dipendente`
--       `Dipendente` -> `CF`
--

--
-- Dumping data for table `Turno`
--

INSERT INTO `Turno` (`id`, `cf_dipendente`, `inizio`, `fine`) VALUES
(2, 'FRLVNI98T09F770V', '2019-01-08 03:00:00', '2019-01-08 15:00:00'),
(4, 'FRLVNI98T09F770V', '2018-12-11 12:00:00', '2018-12-12 00:00:00'),
(5, 'FRLVNI98T09F770V', '2019-01-08 06:00:00', '2019-01-08 17:00:00'),
(6, 'VRDGN77R10G224Z', '2019-01-07 05:00:00', '2019-01-07 12:26:22'),
(7, 'VRDGN77R10G224Z', '2018-12-10 20:00:00', '2018-12-11 05:09:51'),
(8, 'FRLVNI98T09F770V', '2019-01-14 07:00:00', '2019-01-14 12:00:00'),
(11, 'FRLVNI98T09F770V', '2019-01-15 07:00:00', '2019-01-15 08:00:00'),
(12, 'FRLVNI98T09F770V', '2019-01-21 06:20:00', '2019-01-21 06:42:00'),
(13, 'WTFYSV73C11S161T', '2019-01-21 06:35:00', '2019-01-21 06:57:00'),
(14, 'SGWLBP43S78F385N', '2019-01-21 07:00:00', '2019-01-21 08:00:00'),
(15, 'WXGMWB44X13D576N', '2019-01-21 08:00:00', '2019-01-21 09:15:00'),
(16, 'FRLVNI98T09F770V', '2019-01-20 06:20:00', '2019-01-20 06:42:00'),
(17, 'XDJXFS05Z16K926A', '2019-01-06 22:00:00', '2019-01-06 17:00:00');

--
-- Triggers `Turno`
--
DROP TRIGGER IF EXISTS `checkValiditaInsert`;
DELIMITER $$
CREATE TRIGGER `checkValiditaInsert` BEFORE INSERT ON `Turno` FOR EACH ROW BEGIN
	IF(NEW.fine <= NEW.inizio) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "L'orario del turno non e' corretto. La fine deve essere successiva all'inizio del turno";
	END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `checkValiditaUpdate`;
DELIMITER $$
CREATE TRIGGER `checkValiditaUpdate` BEFORE UPDATE ON `Turno` FOR EACH ROW BEGIN
	IF(NEW.fine <= NEW.inizio) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "L'orario del turno non e' corretto. La fine deve essere successiva all'inizio del turno";
	END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `Viaggio`
--
-- Creation: Jun 18, 2019 at 03:49 PM
--

DROP TABLE IF EXISTS `Viaggio`;
CREATE TABLE `Viaggio` (
  `id` int(11) NOT NULL,
  `linea` char(5) NOT NULL,
  `corsa` int(11) NOT NULL,
  `giorno` date NOT NULL,
  `conducente` char(16) NOT NULL,
  `id_mezzo` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- RELATIONS FOR TABLE `Viaggio`:
--   `conducente`
--       `Dipendente` -> `CF`
--   `id_mezzo`
--       `Mezzo` -> `matricola`
--

--
-- Dumping data for table `Viaggio`
--

INSERT INTO `Viaggio` (`id`, `linea`, `corsa`, `giorno`, `conducente`, `id_mezzo`) VALUES
(5, 'E99A', 1, '2019-01-14', 'FRLVNI98T09F770V', 2),
(8, 'E99A', 1, '2019-01-15', 'FRLVNI98T09F770V', 2),
(12, 'U03A', 1, '2019-01-21', 'FRLVNI98T09F770V', 12),
(13, 'U03A', 3, '2019-01-21', 'WTFYSV73C11S161T', 16),
(14, 'E99A', 1, '2019-01-21', 'SGWLBP43S78F385N', 20),
(15, 'E99D', 1, '2019-01-21', 'WXGMWB44X13D576N', 6),
(16, 'U03A', 1, '2019-01-20', 'FRLVNI98T09F770V', 14);

--
-- Triggers `Viaggio`
--
DROP TRIGGER IF EXISTS `AggiuntaTurno`;
DELIMITER $$
CREATE TRIGGER `AggiuntaTurno` AFTER INSERT ON `Viaggio` FOR EACH ROW BEGIN

	DECLARE part TIME;
	DECLARE arr TIME;
	DECLARE idTurnoP INT;
	DECLARE idTurnoA INT;

	SELECT O.ora INTO part FROM Orario O WHERE O.linea = NEW.linea AND O.corsa = NEW.corsa AND O.id_fermata = stazionePartenzaLinea(NEW.linea);
	SELECT O.ora INTO arr FROM Orario O WHERE O.linea = NEW.linea AND O.corsa = NEW.corsa AND O.id_fermata = stazioneArrivoLinea(NEW.linea);

	SET idTurnoP =0;

	SELECT T.id INTO idTurnoP
	FROM Turno T 
	WHERE NEW.conducente = T.cf_dipendente 
	AND T.inizio BETWEEN 
	    TIMESTAMP(
		NEW.giorno,part
	    ) AND TIMESTAMP(
		NEW.giorno,arr
	    );

	IF idTurnoP <> 0 THEN
		UPDATE Turno T SET T.inizio = TIMESTAMP(NEW.giorno,part) WHERE T.id=idTurnoP;
	END IF;

	SET idTurnoA =0;

	SELECT T.id INTO idTurnoA
	FROM Turno T 
	WHERE NEW.conducente = T.cf_dipendente 
	AND T.inizio BETWEEN 
	    TIMESTAMP(
		NEW.giorno,part
	    ) AND TIMESTAMP(
		NEW.giorno,arr
	    );

	IF idTurnoA <> 0 THEN
		UPDATE Turno T SET T.inizio = TIMESTAMP(NEW.giorno,part) WHERE T.id=idTurnoA;
	END IF;

	IF idTurnoP = 0 AND idTurnoA = 0 THEN
		INSERT INTO Turno(`cf_dipendente`, `inizio`, `fine`) VALUES (NEW.conducente, TIMESTAMP(NEW.giorno,part), TIMESTAMP(NEW.giorno,arr));
	END IF;
END
$$
DELIMITER ;
DROP TRIGGER IF EXISTS `CheckConducente`;
DELIMITER $$
CREATE TRIGGER `CheckConducente` BEFORE INSERT ON `Viaggio` FOR EACH ROW BEGIN 

	DECLARE dip CHAR(16) DEFAULT "";
	SELECT D.CF INTO dip FROM Dipendente D WHERE D.CF=NEW.conducente AND FIND_IN_SET('Conducente',D.Ruolo);

	IF(dip <> NEW.conducente) THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = "Il dipendente non è anche un conducente, o non esiste";
	END IF;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure for view `dettaglioViaggi`
--
DROP TABLE IF EXISTS `dettaglioViaggi`;

CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dettaglioViaggi`  AS  select `V`.`id` AS `idViaggio`,`V`.`giorno` AS `giornoViaggio`,`OP`.`tipo` AS `tipoGiorno`,`V`.`linea` AS `linea`,`V`.`corsa` AS `corsa`,`FP`.`id` AS `idFermataPartenza`,`FP`.`Paese` AS `PaesePartenza`,`FP`.`descrizione` AS `FermataPartenza`,`OP`.`ora` AS `OraPartenza`,`FA`.`id` AS `idFermataArrivo`,`FA`.`Paese` AS `PaeseArrivo`,`FA`.`descrizione` AS `FermataArrivo`,`OA`.`ora` AS `OraArrivo`,`D`.`CF` AS `CFConducente`,concat(`D`.`Nome`,' ',`D`.`Cognome`) AS `NomeConducente`,`M`.`matricola` AS `MatricolaVeicolo`,`M`.`tipo` AS `Veicolo`,`M`.`marca` AS `marcaVeicolo`,`M`.`alimentazione` AS `alimentazioneVeicolo`,`M`.`posti_sedere` AS `posti_sedere`,`M`.`posti_sediaRotelle` AS `posti_sediaRotelle`,`M`.`lunghezza_veicolo_mt` AS `lunghezza_veicolo_mt`,`M`.`larghezza_veicolo_mt` AS `larghezza_veicolo_mt`,`M`.`altezza_veicolo_mt` AS `altezza_veicolo_mt` from ((((((`Viaggio` `V` join `Orario` `OP`) join `Orario` `OA`) join `Fermata` `FP`) join `Fermata` `FA`) join `Dipendente` `D`) join `Mezzo` `M`) where ((`V`.`conducente` = `D`.`CF`) and (`V`.`id_mezzo` = `M`.`matricola`) and (`V`.`linea` = `OP`.`linea`) and (`V`.`corsa` = `OP`.`corsa`) and (`V`.`linea` = `OA`.`linea`) and (`V`.`corsa` = `OA`.`corsa`) and (`OA`.`id_fermata` = `FA`.`id`) and (`OP`.`id_fermata` = `FP`.`id`) and (`V`.`id`,`OA`.`ora`) in (select `VV`.`id` AS `id`,max(`OO`.`ora`) AS `ora` from (`Viaggio` `VV` join `Orario` `OO`) where ((`VV`.`linea` = `OO`.`linea`) and (`VV`.`corsa` = `OO`.`corsa`)) group by `VV`.`id`) and (`V`.`id`,`OP`.`ora`) in (select `VV`.`id` AS `id`,min(`OO`.`ora`) AS `ora` from (`Viaggio` `VV` join `Orario` `OO`) where ((`VV`.`linea` = `OO`.`linea`) and (`VV`.`corsa` = `OO`.`corsa`)) group by `VV`.`id`)) order by `V`.`giorno`,`OP`.`ora`,`V`.`id` ;

-- --------------------------------------------------------

--
-- Structure for view `dipendentiPerRuolo`
--
DROP TABLE IF EXISTS `dipendentiPerRuolo`;

CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `dipendentiPerRuolo`  AS  select `Dipendente`.`Ruolo` AS `Ruolo`,count(0) AS `numeroDipendenti` from `Dipendente` group by `Dipendente`.`Ruolo` order by `Dipendente`.`Ruolo` ;

-- --------------------------------------------------------

--
-- Structure for view `Linee`
--
DROP TABLE IF EXISTS `Linee`;

CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `Linee`  AS  select distinct `O`.`linea` AS `linea`,concat(`FP`.`Paese`,' ',`FP`.`descrizione`,' - ',`FA`.`Paese`,' ',`FA`.`descrizione`) AS `Descrizione`,`FP`.`id` AS `idStazionePartenza`,concat(`FP`.`Paese`,' ',`FP`.`descrizione`) AS `stazionePartenza`,`FA`.`id` AS `idStazioneArrivo`,concat(`FA`.`Paese`,' ',`FA`.`descrizione`) AS `stazioneArrivo` from ((`Orario` `O` join `Fermata` `FA`) join `Fermata` `FP`) where ((`O`.`id_fermata` = `stazionePartenzaLinea`(`O`.`linea`)) and (`O`.`id_fermata` = `FP`.`id`) and (`FA`.`id` = `stazioneArrivoLinea`(`O`.`linea`))) ;

-- --------------------------------------------------------

--
-- Structure for view `StipendiUltimoMese`
--
DROP TABLE IF EXISTS `StipendiUltimoMese`;

CREATE ALGORITHM=UNDEFINED SQL SECURITY DEFINER VIEW `StipendiUltimoMese`  AS  select `D`.`CF` AS `CF`,concat(`D`.`Cognome`,' ',`D`.`Nome`) AS `Nome`,`D`.`Ruolo` AS `Ruolo`,date_format((curdate() - interval 1 month),'%M') AS `Mese`,`D`.`costoOrario` AS `costoOrario`,`oreMeseSolareDipendente`(`D`.`CF`,extract(month from (curdate() - interval 1 month)),extract(year from (curdate() - interval 1 month))) AS `Ore`,`calcoloStipendioDipendente`(`D`.`CF`,extract(month from (curdate() - interval 1 month)),extract(year from (curdate() - interval 1 month))) AS `Stipendio` from `Dipendente` `D` order by `oreMeseSolareDipendente`(`D`.`CF`,extract(month from (curdate() - interval 1 month)),extract(year from (curdate() - interval 1 month))),`calcoloStipendioDipendente`(`D`.`CF`,extract(month from (curdate() - interval 1 month)),extract(year from (curdate() - interval 1 month))) desc ;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `Biglietto`
--
ALTER TABLE `Biglietto`
  ADD PRIMARY KEY (`id`),
  ADD KEY `Partenza_Biglietto` (`fermata_partenza`),
  ADD KEY `Arrivo_Biglietto` (`fermata_arrivo`),
  ADD KEY `Tariffa_Biglietto` (`nome_tariffa`);

--
-- Indexes for table `Deposito`
--
ALTER TABLE `Deposito`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `Dipendente`
--
ALTER TABLE `Dipendente`
  ADD PRIMARY KEY (`CF`);

--
-- Indexes for table `Fermata`
--
ALTER TABLE `Fermata`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `Mezzo`
--
ALTER TABLE `Mezzo`
  ADD PRIMARY KEY (`matricola`),
  ADD KEY `Deposito_Mezzo` (`deposito`);

--
-- Indexes for table `Orario`
--
ALTER TABLE `Orario`
  ADD PRIMARY KEY (`linea`,`corsa`,`id_fermata`) USING BTREE,
  ADD KEY `Fermata` (`id_fermata`);

--
-- Indexes for table `Tariffa`
--
ALTER TABLE `Tariffa`
  ADD PRIMARY KEY (`nome`);

--
-- Indexes for table `Turno`
--
ALTER TABLE `Turno`
  ADD PRIMARY KEY (`id`),
  ADD KEY `Dipendente_Turno` (`cf_dipendente`);

--
-- Indexes for table `Viaggio`
--
ALTER TABLE `Viaggio`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `linea` (`linea`,`corsa`,`giorno`),
  ADD KEY `Conducente_Viaggio` (`conducente`),
  ADD KEY `Mezzo_viaggio` (`id_mezzo`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `Biglietto`
--
ALTER TABLE `Biglietto`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;
--
-- AUTO_INCREMENT for table `Deposito`
--
ALTER TABLE `Deposito`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;
--
-- AUTO_INCREMENT for table `Fermata`
--
ALTER TABLE `Fermata`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;
--
-- AUTO_INCREMENT for table `Mezzo`
--
ALTER TABLE `Mezzo`
  MODIFY `matricola` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=27;
--
-- AUTO_INCREMENT for table `Turno`
--
ALTER TABLE `Turno`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=18;
--
-- AUTO_INCREMENT for table `Viaggio`
--
ALTER TABLE `Viaggio`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=17;
--
-- Constraints for dumped tables
--

--
-- Constraints for table `Biglietto`
--
ALTER TABLE `Biglietto`
  ADD CONSTRAINT `Arrivo_Biglietto` FOREIGN KEY (`fermata_arrivo`) REFERENCES `Fermata` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  ADD CONSTRAINT `Partenza_Biglietto` FOREIGN KEY (`fermata_partenza`) REFERENCES `Fermata` (`id`) ON DELETE NO ACTION ON UPDATE CASCADE,
  ADD CONSTRAINT `Tariffa_Biglietto` FOREIGN KEY (`nome_tariffa`) REFERENCES `Tariffa` (`nome`) ON DELETE NO ACTION ON UPDATE CASCADE;

--
-- Constraints for table `Mezzo`
--
ALTER TABLE `Mezzo`
  ADD CONSTRAINT `Deposito_Mezzo` FOREIGN KEY (`deposito`) REFERENCES `Deposito` (`id`) ON DELETE SET NULL ON UPDATE CASCADE;

--
-- Constraints for table `Orario`
--
ALTER TABLE `Orario`
  ADD CONSTRAINT `Fermata` FOREIGN KEY (`id_fermata`) REFERENCES `Fermata` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

--
-- Constraints for table `Turno`
--
ALTER TABLE `Turno`
  ADD CONSTRAINT `Dipendente_Turno` FOREIGN KEY (`cf_dipendente`) REFERENCES `Dipendente` (`CF`) ON DELETE NO ACTION ON UPDATE CASCADE;

--
-- Constraints for table `Viaggio`
--
ALTER TABLE `Viaggio`
  ADD CONSTRAINT `Conducente_Viaggio` FOREIGN KEY (`conducente`) REFERENCES `Dipendente` (`CF`) ON DELETE NO ACTION ON UPDATE CASCADE,
  ADD CONSTRAINT `Mezzo_viaggio` FOREIGN KEY (`id_mezzo`) REFERENCES `Mezzo` (`matricola`) ON DELETE CASCADE ON UPDATE CASCADE;
SET FOREIGN_KEY_CHECKS=1;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
