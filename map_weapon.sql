# Host: csgogamers.com  (Version 5.7.15-log)
# Date: 2017-08-06 00:58:51
# Generator: MySQL-Front 6.0  (Build 2.20)


#
# Structure for table "map_weapon"
#

CREATE TABLE `map_weapon` (
  `Id` int(11) NOT NULL AUTO_INCREMENT,
  `map` varchar(128) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `weapon` tinyint(3) unsigned NOT NULL DEFAULT '0',
  `x` float(16,6) DEFAULT NULL,
  `y` float(16,6) DEFAULT NULL,
  `z` float(16,6) DEFAULT NULL,
  PRIMARY KEY (`Id`)
) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
