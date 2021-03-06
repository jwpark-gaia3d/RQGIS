#' @title Checking paths to QGIS applications
#' @description `check_apps` checks if software applications necessary to
#'   run QGIS (QGIS and Python plugins) are installed in the correct
#'   locations.
#' @param root Path to the root directory. Usually, this is 'C:/OSGEO4~1', 
#'   '/usr' and '/Applications/QGIS.app/' for the different platforms.
#' @param ... Optional arguments used in `check_apps`. Under Windows,
#'   `set_env` passes function argument `dev` to `check_apps`.
#' @return The function returns a list with the paths to all the necessary 
#'   QGIS-applications.
#' @keywords internal
#' @examples 
#' \dontrun{
#' check_apps()
#' }
#' @author Jannes Muenchow, Patrick Schratz

check_apps <- function(root, ...) { 
  
  if (Sys.info()["sysname"] == "Windows") {
    path_apps <- file.path(root, "apps")
    my_qgis <- grep("qgis", dir(path_apps), value = TRUE)
    # use the LTR (default), if available
    dots <- list(...)
    if (length(dots) > 0 && !isTRUE(dots$dev)) {
      my_qgis <- ifelse("qgis-ltr" %in% my_qgis, "qgis-ltr", my_qgis[1])  
    } else {
      # use ../apps/qgis, i.e. most likely the most recent QGIS version
      my_qgis <- my_qgis[1]
    }
    apps <- c(file.path(path_apps, my_qgis),
              file.path(path_apps, my_qgis, "python\\plugins"))
    apps <- gsub("//|/", "\\\\", apps)
  } else if (Sys.info()["sysname"] == "Linux") {
    # paths to check
    apps <- file.path(root, c("bin/qgis", "share/qgis/python/plugins"))
  } else if (Sys.info()["sysname"] == "Darwin") {
    # paths to check
    apps <- file.path(root, c("Contents", "Contents/Resources/python/plugins"))
  } else {
    stop("Sorry, you can use RQGIS only under Windows and UNIX-based
         operating systems.")
  }
  
  out <- 
    lapply(apps, function(app) {
      if (file.exists(app)) {
        app
      } else {
        path <- NULL
        # apps necessary to run the QGIS-API
        stop("Folder ", dirname(app), " could not be found under ",
             basename(app)," Please install it.")
      }
    })
  names(out) <- c("qgis_prefix_path", "python_plugins")
  # return your result
  out
}

#' @title Open the GRASS online help
#' @description `open_grass_help` opens the GRASS online help for a specific
#'   GRASS geoalgorithm.
#' @param alg The name of the GRASS geoalgorithm for which one wishes to open
#'   the online help.
#' @keywords internal
#' @examples 
#' \dontrun{
#' open_grass_help("grass7:r.sunmask")
#' }
#' @author Jannes Muenchow
open_grass_help <- function(alg) {
  grass_name <- gsub(".*:", "", alg)
  url <- ifelse(grepl(7, alg),
                "http://grass.osgeo.org/grass72/manuals/",
                "http://grass.osgeo.org/grass64/manuals/")
  url_ind <- paste0(url, "full_index.html")
  doc <- RCurl::getURL(url_ind)
  doc2 <- XML::htmlParse(doc)
  root <- XML::xmlRoot(doc2)
  grass_funs <- XML::xpathSApply(root[["body"]], "//a/@href")
  grass_funs <- gsub(".html", "", grass_funs)
  # grass_funs <- grep(".*\\..*", grass_funs, value = TRUE)
  # grass_funs <- grass_funs[!grepl("^http:", grass_funs)]
  # grep("^(d.|db.|g\\.|i.|m.|ps.|r.|r3.|t.|v.)", grass_funs, value = TRUE)
  
  # ind <- paste0(c("d", "db", "g", "i", "m", "ps", "r", "r3", "t", "v"), "\\.")
  # ind <- paste(ind, collapse = "|")
  # ind <- paste0("^(", ind, ")")
  # grass_funs <- grep(ind, grass_funs, value = TRUE)
  if (!grass_name %in% grass_funs) {
    grass_name <- gsub("(.*?*)\\..*", "\\1", grass_name)
  }
  # if the name can still not be found, terminate
  if (!grass_name %in% grass_funs) {
    stop(gsub(".*:", "", alg), " could not be found in the online help!")
  }
  url <- paste0(url, grass_name, ".html")
  utils::browseURL(url)
}

#' @title Set all Windows paths necessary to start QGIS
#' @description Windows helper function to start QGIS application by setting all
#'   necessary path especially through running [run_ini()].
#' @param qgis_env Environment settings containing all the paths to run the QGIS
#'   API. For more information, refer to [set_env()].
#' @return The function changes the system settings using [base::Sys.setenv()].
#' @keywords internal
#' @author Jannes Muenchow
#' @examples 
#' \dontrun{
#' setup_win()
#' }

setup_win <- function(qgis_env = set_env()) {
  # call o4w_env.bat from within R
  # not really sure, if we need the next line (just in case)
  Sys.setenv(OSGEO4W_ROOT = qgis_env$root)
  # shell("ECHO %OSGEO4W_ROOT%")
  # REM start with clean path
  windir <- shell("ECHO %WINDIR%", intern = TRUE)
  Sys.setenv(PATH = paste(file.path(qgis_env$root, "bin", fsep = "\\"), 
                          file.path(windir, "system32", fsep = "\\"),
                          windir,
                          file.path(windir, "WBem", fsep = "\\"),
                          sep = ";"))
  # call all bat-files
  run_ini(qgis_env = qgis_env)
  
  # we need to make sure that qgis-ltr can also be used...
  my_qgis <- gsub(".*\\\\", "", qgis_env$qgis_prefix_path)
  # add the directories where the QGIS libraries reside to search path 
  # of the dynamic linker
  Sys.setenv(PATH = paste(Sys.getenv("PATH"),
                          file.path(qgis_env$root, "apps",
                                    my_qgis, "bin", fsep = "\\"),
                          sep = ";"))
  # set the PYTHONPATH variable, so that QGIS knows where to search for
  # QGIS libraries and appropriate Python modules
  python_path <- Sys.getenv("PYTHONPATH")
  python_add <- file.path(qgis_env$root, "apps", my_qgis, "python", 
                          fsep = "\\")
  if (!grepl(gsub("\\\\", "\\\\\\\\", python_add), python_path)) {
    python_path <- paste(python_path, python_add, sep = ";")    
    Sys.setenv(PYTHONPATH = python_path)
    }

  # defining QGIS prefix path (i.e. without bin)
  Sys.setenv(QGIS_PREFIX_PATH = file.path(qgis_env$root, "apps", my_qgis,
                                          fsep = "\\"))
  # shell.exec("python")  # yeah, it works!!!
  # !!!Try to make sure that the right Python version is used!!!
  use_python(file.path(qgis_env$root, "bin\\python.exe", fsep = "\\"), 
             required = TRUE)
  # We do not need the subsequent test for Linux & Mac since the Python 
  # binary should be always found under  /usr/bin
  
  # compare py_config path with set_env path!!
  a <- py_config()
  py_path <- gsub("\\\\bin.*", "", normalizePath(a$python))
  if (!identical(py_path, qgis_env$root)) {
    stop("Wrong Python binary. Restart R and check again!")
  }
}


#' @title Reproduce o4w_env.bat script in R
#' @description Windows helper function to start QGIS application. Basically, 
#'   the code found in all .bat files found in etc/ini (most likely
#'   "C:/OSGEO4~1/etc/ini") is reproduced within R.
#' @importFrom readr read_file
#' @param qgis_env Environment settings containing all the paths to run the QGIS
#'   API. For more information, refer to [set_env()].
#' @return The function changes the system settings using [base::Sys.setenv()].
#' @keywords internal
#' @author Jannes Muenchow
#' @examples 
#' \dontrun{
#' run_ini()
#' }

run_ini <- function(qgis_env = set_env()) {
  files <- dir(file.path(qgis_env$root, "etc/ini"), full.names = TRUE)
  files <- files[-grep("msvcrt|rbatchfiles", files)]
  root <- gsub("\\\\", "\\\\\\\\", qgis_env$root)
  ls <- lapply(files, function(file) {
    tmp <- read_file(file)
    tmp <- gsub("%OSGEO4W_ROOT%", root, tmp)
    tmp <- strsplit(tmp, split = "\r\n|\n")[[1]]
    tmp
  })
  cmds <- do.call(c, ls)
  # remove everything followed by a semi-colon but not if the colon is followed 
  # by %PATH%
  cmds <- gsub(";%([^PATH]).*", "", cmds)
  cmds <- gsub(";%PYTHONPATH%", "", cmds)  # well, not really elegant...
  for (i in cmds) {
    if (grepl("^(SET|set)", i)) {
      tmp <- gsub("^(SET|set) ", "", i)
      tmp <- strsplit(tmp, "=")[[1]]
      args <- list(tmp[2])
      names(args) <- tmp[1]
      # if the environment variable exists but does not contain our path, add it
      # to the already existing one
      if (Sys.getenv(names(args)) != "" &
          !grepl(gsub("\\\\", "\\\\\\\\", args[[1]]), 
                 Sys.getenv((names(args))))) {
        args[[1]] <- paste(args[[1]], Sys.getenv(names(args)), sep = ";")
        
      } else if (Sys.getenv(names(args)) != "" &
                 grepl(gsub("\\\\", "\\\\\\\\", args[[1]]), 
                        Sys.getenv((names(args))))) {
        # if the environment variable already exists and already contains the
        # correct path, do nothing
        next
      }
      do.call(Sys.setenv, args)
    }
    if (grepl("^(path|PATH)", i)) {
      tmp <- gsub("^(PATH|path) ", "", i)
      path <- Sys.getenv("PATH")
      path <- gsub("\\\\", "\\\\\\\\", path)
      tmp <- gsub("%PATH%", path, tmp)
      Sys.setenv(PATH = tmp)
    }
    if (grepl("^if not defined HOME", i)) {
      if (Sys.getenv("HOME") == "") {
        use_prof <- shell("ECHO %USERPROFILE%", intern = TRUE)
        Sys.setenv(HOME = use_prof)
      }
    }
  }
}

#' @title Reset PATH
#' @description Since [run_ini()] starts with a clean PATH, this function makes 
#'   sure to add the original paths to PATH. Note that this function is a
#'   Windows-only function.
#' @param settings A list as derived from `as.list(Sys.getenv())`.
#' @author Jannes Muenchow
reset_path <- function(settings) {
  # PATH re-setting: not the most elegant solution...
  
  if (Sys.info()["sysname"] == "Windows") {
    # first delete any other Anaconda or Python installations from PATH
    tmp <- grep("Anaconda|Python", unlist(strsplit(settings$PATH, ";")),
                value = TRUE)
    # we don't want to delete any paths containing OSGEO (and Python)
    if (any(grepl("OSGeo", tmp))) {
      tmp <- tmp[-grep("OSGeo", tmp)]  
    }
      # replace \\ by \\\\ and collapse by |
    tmp <- paste(gsub("\\\\", "\\\\\\\\", tmp), collapse = "|")
    # delete it from settings
    repl <- gsub(tmp, "", settings$PATH)
    # get rid off repeated semi-colons
    settings$PATH <- gsub(";+", ";", repl)
    
    # We need to make sure to not append over and over again the same paths
    # when running open_app several times
    if (grepl(gsub("\\\\", "\\\\\\\\", Sys.getenv("PATH")), settings$PATH)) {
      # if the OSGeo stuff is already in PATH (which is the case after having
      # run open_app for the fist time), use exactly this PATH
      Sys.setenv(PATH = settings$PATH)
    } else {
      # if the OSGeo stuff has not already been appended (as is the case when
      # running open_app for the first time), append it
      paths <- paste(Sys.getenv("PATH"), settings$PATH, sep = ";")  
      Sys.setenv(PATH = paths)
    }  
  }
}




#' @title Set all Linux paths necessary to start QGIS
#' @description Helper function to start QGIS application under Linux.
#' @param qgis_env Environment settings containing all the paths to run the QGIS
#'   API. For more information, refer to [set_env()].
#' @return The function changes the system settings using [base::Sys.setenv()].
#' @keywords internal
#' @author Jannes Muenchow
#' @examples 
#' \dontrun{
#' setup_linux()
#' }

setup_linux <- function(qgis_env = set_env()) {
  # append PYTHONPATH to import qgis.core etc. packages
  python_path <- Sys.getenv("PYTHONPATH")
  qgis_python_path <- paste0(qgis_env$root, "/share/qgis/python")
  reg_exp <- grepl(paste0(qgis_python_path, ":"), python_path) | 
    grepl(paste0(qgis_python_path, "$"), python_path)
  if (python_path != "" & reg_exp) {
    qgis_python_path <- python_path
  } else if (python_path != "" & !reg_exp) {
    qgis_python_path <- paste(qgis_python_path, Sys.getenv("PYTHONPATH"), 
                              sep = ":")
  }
  Sys.setenv(PYTHONPATH = qgis_python_path)
  # append LD_LIBRARY_PATH
  ld_lib_path <- Sys.getenv("LD_LIBRARY_PATH")
  qgis_ld_path <-  file.path(qgis_env$root, "lib")
  reg_exp <- grepl(paste0(qgis_ld_path, ":"), ld_lib_path) | 
    grepl(paste0(qgis_ld_path, "$"), ld_lib_path)
  if (ld_lib_path != "" & reg_exp) {
    qgis_ld_path <- ld_lib_path
  } else if (ld_lib_path != "" & !reg_exp) {
    qgis_ld_path <- paste(qgis_ld_path, Sys.getenv("LD_LIBRARY_PATH"), 
                          sep = ":")
  }
  Sys.setenv(LD_LIBRARY_PATH = qgis_ld_path)
  # setting here the QGIS_PREFIX_PATH also works instead of running it twice
  # later on
  Sys.setenv(QGIS_PREFIX_PATH = qgis_env$root)
}


#' @title Set all Mac paths necessary to start QGIS
#' @description Helper function to start QGIS application under macOS.
#' @param qgis_env Environment settings containing all the paths to run the QGIS
#'   API. For more information, refer to [set_env()].
#' @return The function changes the system settings using [base::Sys.setenv()].
#' @keywords internal
#' @author Patrick Schratz
#' @examples 
#' \dontrun{
#' setup_mac()
#' }

setup_mac <- function(qgis_env = set_env()) {
  
  # append PYTHONPATH to import qgis.core etc. packages
  python_path <- Sys.getenv("PYTHONPATH")
  
  qgis_python_path <- 
    paste0(qgis_env$root, paste("/Contents/Resources/python/", 
                                "/usr/local/lib/qt-4/python2.7/site-packages",
                                "/usr/local/lib/python2.7/site-packages",
                                "$PYTHONPATH", sep = ":"))
  if (python_path != "" & !grepl(qgis_python_path, python_path)) {
    qgis_python_path <- paste(qgis_python_path, Sys.getenv("PYTHONPATH"), 
                              sep = ":")
  }
  
  Sys.setenv(QGIS_PREFIX_PATH = paste0(qgis_env$root, "/Contents/MacOS/"))
  Sys.setenv(PYTHONPATH = qgis_python_path)
  
  # define path where QGIS libraries reside to search path of the
  # dynamic linker
  ld_library <- Sys.getenv("LD_LIBRARY_PATH")
  
  qgis_ld <- paste(paste0(qgis_env$qgis_prefix_path, 
                          file.path("/MacOS/lib/:/Applications/QGIS.app/", 
                                    "Contents/Frameworks/"))) # homebrew
  if (ld_library != "" & !grepl(paste0(qgis_ld, ":"), ld_library)) {
    qgis_ld <- paste(paste0(qgis_env$root, "/lib"),
                     Sys.getenv("LD_LIBRARY_PATH"), sep = ":")
  }
  Sys.setenv(LD_LIBRARY_PATH = qgis_ld)
  
  # suppress verbose QGIS output for homebrew
  Sys.setenv(QGIS_DEBUG = -1)
}

#' @title Save spatial objects
#' @description The function saves spatial objects (`sp`, `sf` and `raster`) to 
#'   a temporary folder on the computer's hard drive.
#' @param params A parameter-argument list as returned by [pass_args()].
#' @param type_name A character string containing the QGIS parameter type for
#'   each parameter (boolean, multipleinput, extent, number, etc.) of `params`.
#'   The Python method `RQGIS.get_args_man` returns a Python dictionary with one
#'   of its elements corresponding to the type_name (see also the example
#'   section).
#' @keywords internal
#' @examples 
#' \dontrun{
#' library("RQGIS")
#' library("raster")
#' library("reticulate")
#' r <- raster(ncol = 100, nrow = 100)
#' r1 <- crop(r, extent(-10, 11, -10, 11))
#' r2 <- crop(r, extent(0, 20, 0, 20))
#' r3 <- crop(r, extent(9, 30, 9, 30))
#' r1[] <- 1:ncell(r1)
#' r2[] <- 1:ncell(r2)
#' r3[] <- 1:ncell(r3)
#' alg <- "grass7:r.patch"
#' out <- py_run_string(sprintf("out = RQGIS.get_args_man('%s')", alg))$out
#' params <- get_args_man(alg)
#' params$input <- list(r1, r2, r3)
#' params[] <- save_spatial_objects(params = params, 
#'                                  type_name = out$type_name)
#' }
#' @author Jannes Muenchow
save_spatial_objects <- function(params, type_name) {

  lapply(seq_along(params), function(i) {
    tmp <- class(params[[i]])
    if (tmp == "list" && type_name[i] == "multipleinput") {
      names(params[[i]]) <- paste0("inp", 1:length(params[[i]]))
      out <- save_spatial_objects(params = params[[i]])
      return(paste(unlist(out), collapse = ";"))
    }
    
    # GEOMETRY and GEOMETRYCOLLECTION not supported
    if (any(tmp %in% c("sfc_GEOMETRY", "sfc_GEOMETRYCOLLECTION"))) {
      stop("RQGIS does not support GEOMETRY or GEOMETRYCOLLECTION classes")
    }
    # check if the function argument is a SpatialObject
    if (any(grepl("^Spatial(Points|Lines|Polygons)DataFrame$", tmp)) | 
        any(tmp %in% c("sf", "sfc", "sfg"))) {
      # if it is an sp-object convert it into sf, if it already is an attributed
      # sf-object, nothing happens
      params[[i]] <- st_as_sf(params[[i]])
      # write sf as a shapefile to a temporary location while overwriting any
      # previous versions, I don't know why but sometimes the overwriting does 
      # not work...
      fname <- file.path(tempdir(), paste0(names(params)[i], ".shp"))
      cap <- capture.output({
        suppressWarnings(
          test <- 
            try(write_sf(params[[i]], fname, quiet = TRUE), silent = TRUE)
        )
      })
      if (inherits(test, "try-error")) {
        while (tolower(basename(fname)) %in% tolower(dir(tempdir()))) {
          fname <- paste0(gsub(".shp", "", fname), 1, ".shp")  
        }
        write_sf(params[[i]], fname, quiet = TRUE)
      }
      # return the result
      fname
    } else if (tmp == "RasterLayer") {
      fname <- file.path(tempdir(), paste0(names(params)[[i]], ".tif"))
      suppressWarnings(
        test <- 
          try(writeRaster(params[[i]], filename = fname, format = "GTiff", 
                          prj = TRUE, overwrite = TRUE), silent = TRUE)
      )
      if (inherits(test, "try-error")) {
        while (tolower(basename(fname)) %in% tolower(dir(tempdir()))) {
          fname <- paste0(gsub(".tif", "", fname), 1, ".tif")  
        }
        writeRaster(params[[i]], filename = fname, format = "GTiff", 
                    prj = TRUE, overwrite = TRUE)
      }
      # return the result
      fname
    }  else {
      params[[i]]
    }
  })
}

#' @title Retrieve the `GRASS_REGION_PARAMETER`
#' @description Retrieve the `GRASS_REGION_PARAMETER` by running through a 
#'   parameter-argument list while merging the extents of all spatial objects.
#' @param params A parameter-argument list as returned by [pass_args()].
#' @param type_name A character string containing the QGIS parameter type for 
#'   each parameter (boolean, multipleinput, extent, number, etc.) of `params`. 
#'   The Python method `RQGIS.get_args_man` returns a Python dictionary with one
#'   of its elements corresponding to the type_name (see also the example
#'   section).
#' @keywords internal
#' @examples 
#' \dontrun{
#' library("RQGIS")
#' library("raster")
#' library("reticulate")
#' r <- raster(ncol = 100, nrow = 100)
#' r1 <- crop(r, extent(-10, 11, -10, 11))
#' r2 <- crop(r, extent(0, 20, 0, 20))
#' r3 <- crop(r, extent(9, 30, 9, 30))
#' r1[] <- 1:ncell(r1)
#' r2[] <- 1:ncell(r2)
#' r3[] <- 1:ncell(r3)
#' alg <- "grass7:r.patch"
#' out <- py_run_string(sprintf("out = RQGIS.get_args_man('%s')", alg))$out
#' params <- get_args_man(alg)
#' params$input <- list(r1, r2, r3)
#' params[] <- save_spatial_objects(alg = alg, params = params, 
#'                                  type_name = out$type_name)
#' get_grp(params = params, type_name = out$type_name)
#' }
#' @author Jannes Muenchow
get_grp <- function(params, type_name) {
  ext <- mapply(function(x, y) {
    if (y == "multipleinput") {
      get_grp(unlist(strsplit(x, split = ";")), "")
    } else {
      # We cannot simply use gsub as we have done before (gsub("[.].*",
      # "",basename(x))) if the filename itself also contains dots, e.g.,
      # gis.osm_roads_free_1.shp 
      # We could use regexp to cut off the file extension
      # my_layer <- stringr::str_extract(basename(x), "[A-z].+[^\\.[A-z]]")
      # but let's use an already existing function
      my_layer <- file_path_sans_ext(basename(as.character(x)))
      # determine bbox in the case of a vector layer
      tmp <- try(expr = ogrInfo(dsn = x, layer = my_layer)$extent, 
                 silent = TRUE)
      if (!inherits(tmp, "try-error")) {
        # check if this is always this way (xmin, ymin, xmax, ymax...)
        extent(tmp[c(1, 3, 2, 4)])
      } else {
        # determine bbox in the case of a raster
        ext <- try(expr = GDALinfo(x, returnStats = FALSE),
                   silent = TRUE)
        # check if it is still an error
        if (!inherits(ext, "try-error")) {
          # xmin, xmax, ymin, ymax
          extent(c(ext["ll.x"], 
                   ext["ll.x"] + ext["columns"] * ext["res.x"],
                   ext["ll.y"],
                   ext["ll.y"] + ext["rows"] * ext["res.y"]))
        } else {
          NA
        }
      }
    }
  }, x = params, y = type_name)
  # now that we have possibly several extents, union them
  ext <- ext[!is.na(ext)]
  ext <- Reduce(raster::merge, ext)
  if (is.null(ext)) {
    stop("Either you forgot to specify an input shapefile/raster or the", 
         " input file does not exist")
  }
  # sometimes the extent is given back with dec = ","; you need to change that
  ext <- gsub(",", ".", ext[1:4])
  ext
}


#' @title Check if RQGIS is loaded on a server 
#' @description Performs cross-platform (Unix, Windows) and OS (Debian/Ubuntu) checks for a server infrastructure 
#' @importFrom parallel detectCores
#' @keywords internal
#' @author Patrick Schratz
#' @export
check_for_server <- function() {
  
  # try to get an output of 'lsb_release -a'
  if (detectCores() > 10 && .Platform$OS.type == "unix") {
    test <- try(suppressWarnings(system2("lsb_release", "-a", stdout = TRUE,
                                         stderr = TRUE)), 
                silent = TRUE)
    if (!inherits(test, "try-error")) { 
      get_regex <- grep("Distributor ID:", test, value = TRUE) 
      platform <- gsub("Distributor ID:\t", "", get_regex) 
      
      # check for Debian | Ubuntu
      if (platform == "Debian") {
        warning(paste0("Hey there! According to our internal checks, you are trying to run RQGIS on a server.\n", 
                       "Please note that this is only possible if you imitate a x-display.\n", 
                       "QGIS needs this in the background to be able to execute its processing modules.\n", 
                       "Since we detected you are running a Debian server, the following R command should solve the problem:\n",
                       "system('export DISPLAY=:99 && xdpyinfo -display $DISPLAY > /dev/null || Xvfb $DISPLAY -screen 99 1024x768x16 &').\n", 
                       "Note that you need to run this as root.", collapse = "\n"))
        # set warn = -1 to only display this warning once per session (warn = -1 ignores warnings commands)
        options(warn = -1)
      }
      if (platform == "Ubuntu") {
        warning(paste0("Hey there! According to our internal checks, you are trying to run RQGIS on a server.\n", 
                       "Please note that this is only possible if you imitate a x-display.\n", 
                       "QGIS needs this in the background to be able to execute its processing modules.\n", 
                       "Since we detected you are running a Debian server, the following R command should solve the problem:\n",
                       "system('export DISPLAY=:99 && /etc/init.d/xvfb && start && sleep 3').\n", 
                       "Note that you need to run this as root.", collapse = "\n"))
        # set warn = -1 to only display this warning once per session (warn = -1 ignores warnings commands)
        options(warn = -1)
      }
    } 
  }
  if (detectCores() > 10 && Sys.info()["sysname"] == "Windows") {
    warning(paste0("Hey there! According to our internal checks, you are trying to run RQGIS on a Windows server.\n", 
                   "Please note that this is only possible if you imitate a x-display.\n", 
                   "QGIS needs this in the background to be able to execute its processing modules.\n", 
                   "Note that you need to start the x-display with admin rights", collapse = "\n"))
    # set warn = -1 to only display this warning once per session (warn = -1 ignores warnings commands)
    options(warn = -1)
  }
}


