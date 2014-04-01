# Description:
#   Github issue linker based on tenfef's script.
#   Links to an issue based on any of the following templates:
#       * <user>/<repo>#<issuenumber>
#       * <alias>#<issuenumber>
#       * <plaintext mentioning alias> #<issuenumber> <plaintext mentioning alias>
#   Aliases are configured in a coffeescript object in this script. 
#   Ultimately the repo defaults to HUBOT_GITHUB_REPO if the message doesn't mention a repo or alias
#
# Dependencies:
#   "githubot": "0.4.x"
#
# Configuration:
#   HUBOT_GITHUB_REPO
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_API
#   HUBOT_GITHUB_ISSUE_LINK_IGNORE_USERS
#
# Commands:
#   #nnn - link to GitHub issue nnn for a repo inferred by surrounding text, or HUBOT_GITHUB_REPO if none
#   repo#nnn - link to GitHub issue nnn for repo project
#   user/repo#nnn - link to GitHub issue nnn for user/repo project
#
# Notes:
#   HUBOT_GITHUB_API allows you to set a custom URL path (for Github enterprise users)
#
# Author:
#   wgreenberg

REPO_ALIASES = 
  sdk: "endlessm/eos-sdk"
  shell: "endlessm/eos-shell"

LABEL_KEYWORDS = [
  'blocked',
  'backlog',
  'fail'
  'revise',
  'dev',
  'review',
  'ready',
  'qa',
  'complete'
]

LABEL_COLORS = {
  'Complete': 'green',
  'Backlog': 'grey',
  'Blocked': 'maroon',
  'Revise': 'red',
  'Review ready': 'purple',
  'Review': 'purple',
  'QA': 'lightblue',
  'Dev': 'blue',
  'Dev ready': 'aqua'
}

get_label_color = (label) ->
  if label in Object.keys(LABEL_COLORS)
    return LABEL_COLORS[label]
  return null

get_issue_status = (issue_obj) ->
  label_objs = issue_obj.labels
  labels = label_objs.map((obj) -> return obj.name)
  prefix_regex = /^\d+ +- +(.*)$/
  is_keyword = (label) ->
    for keyword in LABEL_KEYWORDS 
      if label.toLowerCase().indexOf(keyword) > -1
        return true 
    return false
  status_labels = labels.filter is_keyword

  if status_labels.length > 0
    status = status_labels[0]
    if match = prefix_regex.exec(status)
      return [match[1], get_label_color(match[1])]
    return [status, get_label_color(status)]
  else
    default_label = issue_obj.state.toUpperCase()
    return [default_label, get_label_color(default_label)]

get_alias = (message) ->
  first_alias_occurance = message.length
  first_alias = null
  for alias in Object.keys(REPO_ALIASES)
    if message.match(alias)
      this_alias_occurance = message.indexOf(alias)
      if this_alias_occurance < first_alias_occurance
        first_alias_occurance = this_alias_occurance
        first_alias = alias

  return first_alias


infer_repo = (message, match) ->
  issue_repo = match[2]
  if issue_repo == undefined
    # infer whether we're talking about shell or sdk
    aliased = get_alias message
    if aliased
      return REPO_ALIASES[aliased]
    else
      return process.env.HUBOT_GITHUB_REPO
  else if issue_repo in Object.keys(REPO_ALIASES)
    return REPO_ALIASES[issue_repo]

  return issue_repo

module.exports = (robot) ->
  github = require("githubot")(robot)
  colors = require("irc-colors")

  issue_regexp = /(([\w-]*|^)?#(\d+))/g

  githubIgnoreUsers = process.env.HUBOT_GITHUB_ISSUE_LINK_IGNORE_USERS
  if githubIgnoreUsers == undefined
    githubIgnoreUsers = "github|hubot"

  adminUser = process.env.HUBOT_AUTH_ADMIN || "your favorite sysadmin"

  robot.hear /.*((\S*|^)?#(\d+)).*/, (msg) ->
    return if msg.message.user.name.match(new RegExp(githubIgnoreUsers, "gi"))
    
    message = msg.match[0]
    while match = issue_regexp.exec(message)
      issue_number = match[3]
      if isNaN(issue_number)
        return
      
      issue_title = ""
      bot_github_repo = github.qualified_repo(infer_repo(message, match))
      base_url = process.env.HUBOT_GITHUB_API || 'https://api.github.com'

      issue_message_generator = (repo, number) ->
        (issue_obj) ->
          issue_title = issue_obj.title
          unless process.env.HUBOT_GITHUB_API
            url = "https://github.com"
          else
            url = base_url.replace /\/api\/v3/, ''

          try
            [status, color] = get_issue_status(issue_obj)

            if color
              status_str = colors.bold[color]("[#{status}]")
            else
              status_str = colors.bold("[#{status}]")
            issue_title_str = issue_title
            repo_str = "#{repo}##{number}"
            url_str = colors.underline("#{url}/#{repo}/issues/#{number}")
            msg.send "#{status_str} #{repo_str}: #{issue_title_str} #{url_str}"
          catch e
            console.log e
            msg.send "ohnoes, something broke! bug #{adminUser} about this"
      
      github.get "#{base_url}/repos/#{bot_github_repo}/issues/" + issue_number, issue_message_generator(bot_github_repo, issue_number)
