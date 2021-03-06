#' @importFrom R6 R6Class
#' @importFrom Rcpp evalCpp
simmer.trajectory <- R6Class("simmer.trajectory",
  public = list(
    name = NA,

    initialize = function(name="anonymous", verbose=FALSE) {
      self$name <- evaluate_value(name)
      private$verbose <- evaluate_value(verbose)
      self
    },

    print = function(indent=0) {
      margin <- paste(rep(" ", indent), collapse = "")
      cat(paste0(margin, "simmer trajectory: ", self$name, ", ",
                 private$n_activities, " activities\n"))
      ptr <- self$get_head()
      while (!identical(ptr, self$get_tail())) {
        activity_print_(ptr, indent)
        ptr <- activity_get_next_(ptr)
      }
      if (!is.null(ptr)) activity_print_(ptr, indent)
    },

    get_head = function() { private$ptrs[[1]] },

    get_tail = function() { private$ptrs[[length(private$ptrs)]] },

    get_n_activities = function() { private$n_activities },

    seize = function(resource, amount=1, id=0, continue=NULL, post.seize=NULL, reject=NULL) {
      resource <- evaluate_value(resource)
      amount <- evaluate_value(amount)
      id <- evaluate_value(id)
      trj <- list()
      mask <- 0
      if (!is.null(post.seize)) {
        if (!inherits(post.seize, "simmer.trajectory")) stop("not a trajectory")
        trj <- c(trj, post.seize)
        mask <- mask + 1
      }
      if (!is.null(reject)) {
        if (!inherits(reject, "simmer.trajectory")) stop("not a trajectory")
        trj <- c(trj, reject)
        mask <- mask + 2
      }
      if (length(continue) != length(trj))
        stop("the number of elements does not match")
      if (!length(continue)) continue <- TRUE

      if (is.na(resource)) {
        if (is.function(amount))
          private$add_activity(SeizeSelected__new_func(private$verbose, id, amount, needs_attrs(amount),
                                                       continue, trj, mask))
        else private$add_activity(SeizeSelected__new(private$verbose, id, amount, continue, trj, mask))
      } else {
        if (is.function(amount))
          private$add_activity(Seize__new_func(private$verbose, resource, amount, needs_attrs(amount),
                                               continue, trj, mask))
        else private$add_activity(Seize__new(private$verbose, resource, amount, continue, trj, mask))
      }
    },

    release = function(resource, amount=1, id=0) {
      resource <- evaluate_value(resource)
      amount <- evaluate_value(amount)
      id <- evaluate_value(id)
      if (is.na(resource)) {
        if (is.function(amount))
          private$add_activity(ReleaseSelected__new_func(private$verbose, id, amount, needs_attrs(amount)))
        else private$add_activity(ReleaseSelected__new(private$verbose, id, amount))
      } else {
        if (is.function(amount))
          private$add_activity(Release__new_func(private$verbose, resource, amount, needs_attrs(amount)))
        else private$add_activity(Release__new(private$verbose, resource, amount))
      }
    },

    select = function(resources, policy=c("shortest-queue", "round-robin",
                                          "first-available", "random"), id=0) {
      resources <- evaluate_value(resources)
      policy <- match.arg(policy)
      id <- evaluate_value(id)
      if (is.function(resources))
        private$add_activity(Select__new_func(private$verbose, resources, needs_attrs(resources), id))
      else private$add_activity(Select__new(private$verbose, resources, policy, id))
    },

    timeout = function(task) {
      task <- evaluate_value(task)
      if (is.function(task))
        private$add_activity(Timeout__new_func(private$verbose, task, needs_attrs(task)))
      else private$add_activity(Timeout__new(private$verbose, task))
    },

    set_attribute = function(key, value) {
      key <- as.character(key)
      value <- evaluate_value(value)
      if (is.function(value))
        private$add_activity(SetAttribute__new_func(private$verbose, key, value, needs_attrs(value)))
      else private$add_activity(SetAttribute__new(private$verbose, key, value))
    },

    set_prioritization = function(values) {
      if (is.function(values))
        private$add_activity(SetPrior__new_func(private$verbose, values, needs_attrs(values)))
      else private$add_activity(SetPrior__new(private$verbose, values))
    },

    branch = function(option, continue, ...) {
      trj <- list(...)
      if (length(continue) != length(trj))
        stop("the number of elements does not match")
      for (i in trj) if (!inherits(i, "simmer.trajectory"))
        stop("not a trajectory")
      private$add_activity(Branch__new(private$verbose, option, needs_attrs(option), continue, trj))
    },

    rollback = function(amount, times=1, check) {
      amount <- evaluate_value(amount)
      times <- evaluate_value(times)
      if (is.infinite(times)) times <- -1
      if (missing(check))
        private$add_activity(Rollback__new(private$verbose, amount, times))
      else private$add_activity(Rollback__new_func(private$verbose, amount, check, needs_attrs(check)))
    },

    leave = function(prob) {
      prob <- evaluate_value(prob)
      if (is.function(prob))
        private$add_activity(Leave__new_func(private$verbose, prob, needs_attrs(prob)))
      else private$add_activity(Leave__new(private$verbose, prob))
    },

    renege_in = function(t, out=NULL) {
      t <- evaluate_value(t)
      traj <- list()
      if (!is.null(out)) {
        if (!inherits(out, "simmer.trajectory")) stop("not a trajectory")
        traj <- c(traj, out)
      }
      if (is.function(t))
        private$add_activity(RenegeIn__new_func(private$verbose, t, needs_attrs(t), traj))
      else private$add_activity(RenegeIn__new(private$verbose, t, traj))
    },

    renege_abort = function() { private$add_activity(RenegeAbort__new(private$verbose)) },

    replicate = function(n, ...) {
      n <- evaluate_value(n)
      trj <- list(...)
      for (i in trj) if (!inherits(i, "simmer.trajectory"))
        stop("not a trajectory")
      if (is.function(n))
        private$add_activity(Clone__new_func(private$verbose, n, needs_attrs(n), trj))
      else private$add_activity(Clone__new(private$verbose, n, trj))
    },

    synchronize = function(wait=TRUE, mon_all=FALSE) {
      wait <- evaluate_value(wait)
      mon_all <- evaluate_value(mon_all)
      private$add_activity(Synchronize__new(private$verbose, wait, mon_all))
    },

    batch = function(n, timeout=0, permanent=FALSE, name="", rule=NULL) {
      n <- evaluate_value(n)
      timeout <- evaluate_value(timeout)
      permanent <- evaluate_value(permanent)
      name <- evaluate_value(name)
      if (is.function(rule))
        private$add_activity(Batch__new_func(private$verbose, n, timeout, permanent, name,
                                             rule, needs_attrs(rule)))
      else private$add_activity(Batch__new(private$verbose, n, timeout, permanent, name))
    },

    separate = function() { private$add_activity(Separate__new(private$verbose)) },

    join = function(traj) {
      if (!inherits(traj, "simmer.trajectory"))
        stop("not a trajectory")
      new <- self$clone(deep = TRUE)
      traj <- traj$clone(deep = TRUE)
      if (!is.null(traj$get_head()) && !is.null(new$get_tail()))
          activity_chain_(new$get_tail(), traj$get_head())
      new$.__enclos_env__$private$ptrs <-
        c(new$.__enclos_env__$private$ptrs, traj$.__enclos_env__$private$ptrs)
      new$.__enclos_env__$private$n_activities <-
        new$.__enclos_env__$private$n_activities + traj$get_n_activities()
      new
    }
  ),

  private = list(
    verbose = FALSE,
    n_activities = 0,
    ptrs = NULL,

    add_activity = function(activity) {
      if (!is.null(private$ptrs))
        activity_chain_(self$get_tail(), activity)
      private$ptrs <- c(private$ptrs, activity)
      private$n_activities <- private$n_activities + activity_get_n_(activity)
      self
    },

    clone2 = function(){},
    copy = function(deep = FALSE) {
      new <- private$clone2(deep)
      new$.__enclos_env__$private$ptrs <- NULL
      if (!is.null(self$get_head())) {
        ptr <- self$get_head()
        new_ptr <- activity_clone_(ptr)
        new$.__enclos_env__$private$ptrs <- c(new$.__enclos_env__$private$ptrs, new_ptr)
        while (!identical(ptr, self$get_tail())) {
          ptr <- activity_get_next_(ptr)
          new_ptr <- activity_clone_(ptr)
          activity_chain_(new$get_tail(), new_ptr)
          new$.__enclos_env__$private$ptrs <- c(new$.__enclos_env__$private$ptrs, new_ptr)
        }
      }
      new
    }
  )
)
simmer.trajectory$private_methods$clone2 <- simmer.trajectory$public_methods$clone
simmer.trajectory$public_methods$clone <- simmer.trajectory$private_methods$copy

#' Create a trajectory
#'
#' This method initialises a trajectory object, which comprises a chain of
#' activities that can be attached to a generator.
#'
#' @param name the name of the trajectory.
#' @param verbose enable showing additional information.
#'
#' @return Returns an environment that represents the trajectory.
#' @seealso Methods for dealing with trajectories:
#' \code{\link{get_head}}, \code{\link{get_tail}}, \code{\link{get_n_activities}}, \code{\link{join}},
#' \code{\link{seize}}, \code{\link{release}}, \code{\link{seize_selected}}, \code{\link{release_selected}},
#' \code{\link{select}}, \code{\link{set_prioritization}}, \code{\link{set_attribute}},
#' \code{\link{timeout}}, \code{\link{branch}}, \code{\link{rollback}}, \code{\link{leave}},
#' \code{\link{renege_in}}, \code{\link{renege_abort}},\code{\link{clone}}, \code{\link{synchronize}},
#' \code{\link{batch}}, \code{\link{separate}}.
#' @export
#'
#' @examples
#' t0 <- create_trajectory("my trajectory") %>%
#'   ## add an intake activity
#'   seize("nurse", 1) %>%
#'   timeout(function() rnorm(1, 15)) %>%
#'   release("nurse", 1) %>%
#'   ## add a consultation activity
#'   seize("doctor", 1) %>%
#'   timeout(function() rnorm(1, 20)) %>%
#'   release("doctor", 1) %>%
#'   ## add a planning activity
#'   seize("administration", 1) %>%
#'   timeout(function() rnorm(1, 5)) %>%
#'   release("administration", 1)
#'
#' t0
#'
#' t1 <- create_trajectory("trajectory with a branch") %>%
#'   seize("server", 1) %>%
#'   # 50-50 chance for each branch
#'   branch(function() sample(1:2, 1), continue=c(TRUE, FALSE),
#'     create_trajectory("branch1") %>%
#'       timeout(function() 1),
#'     create_trajectory("branch2") %>%
#'       timeout(function() rexp(1, 3)) %>%
#'       release("server", 1)
#'   ) %>%
#'   # only the first branch continues here
#'   release("server", 1) %>%
#'   timeout(function() 2)
#'
#' t1
create_trajectory <- function(name="anonymous", verbose=FALSE) simmer.trajectory$new(name, verbose)

#' Get the first/last activity
#'
#' Trajectory getters for obtaining the pointer to its first/last activity.
#'
#' @param traj the trajectory object.
#'
#' @return An external pointer to an activity object.
#' @seealso \code{\link{get_n_activities}}, \code{\link{join}}.
#' @export
get_head <- function(traj) traj$get_head()

#' @rdname get_head
#' @export
get_tail <- function(traj) traj$get_tail()

#' Get the number of activities
#'
#' Trajectory getter for obtaining the total number of activities defined inside it.
#'
#' @inheritParams get_head
#'
#' @return The number of activities in the trajectory.
#' @seealso \code{\link{get_head}}, \code{\link{get_tail}}, \code{\link{join}}.
#' @export
get_n_activities <- function(traj) traj$get_n_activities()

#' Join trajectories
#'
#' Concatenate any number of trajectories in the specified order.
#'
#' @param ... trajectory objects.
#'
#' @return A new trajectory object.
#' @seealso \code{\link{get_head}}, \code{\link{get_tail}}, \code{\link{get_n_activities}}.
#' @export
#'
#' @examples
#' t1 <- create_trajectory() %>% seize("dummy", 1)
#' t2 <- create_trajectory() %>% timeout(1)
#' t3 <- create_trajectory() %>% release("dummy", 1)
#'
#' join(t1, t2, t3)
#'
#' create_trajectory() %>%
#'   join(t1) %>%
#'   timeout(1) %>%
#'   join(t3)
join <- function(...) {
  traj <- c(...)
  for (i in traj[-1]) traj[[1]] <- traj[[1]]$join(i)
  traj[[1]]
}

#' Add a seize/release activity
#'
#' Activities for seizing/releasing a resource, by name or a previously selected one.
#'
#' @inheritParams get_head
#' @inheritParams select
#' @param resource the name of the resource.
#' @param amount the amount to seize/release, accepts either a numeric or a callable object
#' (a function) which must return a numeric.
#' @param continue a boolean (if \code{post.seize} OR \code{reject} is defined) or a pair of booleans
#' (if \code{post.seize} AND \code{reject} are defined) to indicate whether these subtrajectories
#' should continue to the next activity in the main trajectory.
#' @param post.seize an optional trajectory object which will be followed after a successful seize.
#' @param reject an optional trajectory object which will be followed if the arrival is rejected.
#'
#' @return The trajectory object.
#' @seealso \code{\link{select}}.
#' @export
seize <- function(traj, resource, amount=1, continue=NULL, post.seize=NULL, reject=NULL)
  traj$seize(resource, amount, 0, continue, post.seize, reject)

#' @rdname seize
#' @export
seize_selected <- function(traj, amount=1, id=0, continue=NULL, post.seize=NULL, reject=NULL)
  traj$seize(NA, amount, id, continue, post.seize, reject)

#' @rdname seize
#' @export
release <- function(traj, resource, amount=1) traj$release(resource, amount)

#' @rdname seize
#' @export
release_selected <- function(traj, amount=1, id=0) traj$release(NA, amount, id)

#' Select a resource
#'
#' Resource selector for a subsequent seize/release.
#'
#' @inheritParams get_head
#' @param resources one or more resource names, or a callable object (a function) which
#' must return a resource name to select.
#' @param policy if \code{resources} is a vector of names, this parameter determines
#' the criteria for selecting a resource among the set of policies available; otherwise,
#' it is ignored.
#' @param id selection identifier for nested usage.
#'
#' @return The trajectory object.
#' @seealso \code{\link{seize_selected}}, \code{\link{release_selected}}.
#' @export
select <- function(traj, resources, policy=c("shortest-queue", "round-robin",
                                             "first-available", "random"), id=0)
  traj$select(resources, policy, id)

#' Add a timeout activity
#'
#' Insert delays and execute user-defined tasks.
#'
#' @inheritParams get_head
#' @param task the timeout duration supplied by either passing a numeric or a
#' callable object (a function) which must return a numeric (negative values are
#' automatically coerced to positive).
#'
#' @return The trajectory object.
#' @export
timeout <- function(traj, task) traj$timeout(task)

#' Add a set attribute activity
#'
#' Modify an attribute in the form of a key/value pair.
#'
#' @inheritParams get_head
#' @param key the attribute key (coerced to a string).
#' @param value the value to set, accepts either a numeric or a callable object
#' (a function) which must return a numeric.
#'
#' @return The trajectory object.
#' @export
set_attribute <- function(traj, key, value) traj$set_attribute(key, value)

#' Add a set prioritization activity
#'
#' Modify the arrival's prioritization values.
#'
#' @inheritParams get_head
#' @param values expects either a vector/list or a callable object (a function)
#' returning a vector/list of three values \code{c(priority, preemptible, restart)}.
#' A negative value leaves the corresponding parameter unchanged.
#' See \code{\link{add_generator}} for more information about these parameters.
#'
#' @return The trajectory object.
#' @export
set_prioritization <- function(traj, values) traj$set_prioritization(values)

#' Add a branch activity
#'
#' Define a fork with \code{N} alternative sub-trajectories.
#'
#' @inheritParams get_head
#' @param option a callable object (a function) which must return an integer between
#' \code{0} and \code{N}. A return value equal to \code{0} skips the branch and
#' continues to the next activity. A returning value between \code{1} to \code{N}
#' makes the arrival to follow the corresponding sub-trajectory.
#' @param continue a vector of \code{N} booleans that indicate whether the arrival must
#' continue to the main trajectory after each sub-trajectory or not.
#' @param ... \code{N} trajectory objects describing each sub-trajectory.
#'
#' @return The trajectory object.
#' @export
branch <- function(traj, option, continue, ...) traj$branch(option, continue, ...)

#' Add a rollback activity
#'
#' Go backwards to a previous point in the trajectory. Useful to implement loops.
#'
#' @inheritParams get_head
#' @param amount the amount of activities (of the same or parent trajectories) to roll back.
#' @param times the number of repetitions until an arrival may continue.
#' @param check a callable object (a function) which must return a boolean. If
#' present, the \code{times} parameter is ignored, and the activity uses this
#' function to check whether the rollback must be done or not.
#'
#' @return The trajectory object.
#' @export
rollback <- function(traj, amount, times=1, check) traj$rollback(amount, times, check)

#' Add a leave activity
#'
#' Leave the trajectory with some probability.
#'
#' @inheritParams get_head
#' @param prob a probability or a function returning a probability.
#'
#' @return The trajectory object.
#' @export
leave <- function(traj, prob) traj$leave(prob)

#' Add a renege activity
#'
#' Set or unset a timer after which the arrival will abandon.
#'
#' @inheritParams get_head
#' @param t timeout to trigger reneging, accepts either a numeric or a callable object
#' (a function) which must return a numeric.
#' @param out optional sub-trajectory in case of reneging.
#'
#' @return The trajectory object.
#' @export
renege_in <- function(traj, t, out=NULL) traj$renege_in(t, out)

#' @inheritParams get_head
#'
#' @rdname renege_in
#' @export
renege_abort <- function(traj) traj$renege_abort()

#' Add a clone/synchronize activity
#'
#' A \code{clone} activity replicates an arrival \code{n} times (the original
#' one + \code{n-1} copies). A \code{synchronize} activity removes all but one clone.
#'
#' @inheritParams get_head
#' @param n number of clones, accepts either a numeric or a callable object
#' (a function) which must return a numeric.
#' @param ... optional parallel sub-trajectories. Each clone will follow
#' a different sub-trajectory if available.
#'
#' @return The trajectory object.
#' @export
clone <- function(traj, n, ...) traj$replicate(n, ...)

#' @inheritParams get_head
#' @param wait if \code{FALSE}, all clones but the first to arrive are removed.
#' if \code{TRUE} (default), all clones but the last to arrive are removed.
#' @param mon_all if \code{TRUE}, \code{get_mon_arrivals} will show one
#' line per clone.
#'
#' @rdname clone
#' @export
synchronize <- function(traj, wait=TRUE, mon_all=FALSE) traj$synchronize(wait, mon_all)

#' Add a batch/separate activity
#'
#' Collect a number of arrivals before they can continue processing
#' or split a previously established batch.
#'
#' @inheritParams get_head
#' @param n batch size, accepts a numeric.
#' @param timeout set an optional timer which triggers batches every \code{timeout} time
#' units even if the batch size has not been fulfilled, accepts a numeric (0 = disabled).
#' @param permanent if \code{TRUE}, batches cannot be split.
#' @param name optional string. Unnamed batches from different \code{batch} activities are
#' independent. However, if you want to feed arrivals from different trajectories into a
#' same batch, you need to specify a common name across all your \code{batch} activities.
#' @param rule an optional callable object (a function) which will be applied to
#' every arrival to determine whether it should be included into the batch, thus
#  it must return a boolean.
#'
#' @return The trajectory object.
#' @export
batch <- function(traj, n, timeout=0, permanent=FALSE, name="", rule=NULL)
  traj$batch(n, timeout, permanent, name, rule)

#' @inheritParams get_head
#'
#' @rdname batch
#' @export
separate <- function(traj) traj$separate()
