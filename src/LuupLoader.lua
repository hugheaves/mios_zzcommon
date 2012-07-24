-- Luup Module Decompression and Load Utility
--
-- Copyright (C) 2012  Hugh Eaves
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


-- Using "require" to access compressed modules doesn't work if the 
-- module is declared without using the "module" function.
-- (see http://bugs.micasaverde.com/view.php?id=2276 )
--
-- We work around this by using pluto-lzo
-- to decompress the module. The temp file is used to
-- avoid a race condition when multiple instances of this module
-- start at the same time. (to prevent one instance from loading a 
-- partially decompressed file from another instance)

module (g_loader_module_name, package.seeall)


