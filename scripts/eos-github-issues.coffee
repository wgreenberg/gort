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

module.exports = (robot) ->
  github = require("githubot")(robot)

  issue_regexp = /((\S*|^)?#(\d+))/g

  githubIgnoreUsers = process.env.HUBOT_GITHUB_ISSUE_LINK_IGNORE_USERS
  if githubIgnoreUsers == undefined
    githubIgnoreUsers = "github|hubot"

  robot.hear /.*((\S*|^)?#(\d+)).*/, (msg) ->
    return if msg.message.user.name.match(new RegExp(githubIgnoreUsers, "gi"))
    
    message = msg.match[0]
    while match = issue_regexp.exec(message)
      issue_number = match[3]
      if isNaN(issue_number)
        return
      
      issue_repo = match[2]
      if issue_repo == undefined
        # infer whether we're talking about shell or sdk
        for alias in Object.keys(REPO_ALIASES)
          if message.match(alias) and bot_github_repo == undefined
            bot_github_repo = github.qualified_repo REPO_ALIASES[alias]
        if bot_github_repo == undefined
          bot_github_repo = github.qualified_repo process.env.HUBOT_GITHUB_REPO
      else if issue_repo in Object.keys(REPO_ALIASES)
        bot_github_repo = github.qualified_repo REPO_ALIASES[issue_repo]
      else
        bot_github_repo = github.qualified_repo issue_repo
      
      issue_title = ""
      base_url = process.env.HUBOT_GITHUB_API || 'https://api.github.com'

      issue_message_generator = (repo, number) ->
        (issue_obj) ->
          issue_title = issue_obj.title
          unless process.env.HUBOT_GITHUB_API
            url = "https://github.com"
          else
            url = base_url.replace /\/api\/v3/, ''
          msg.send "#{repo}##{number}: #{issue_title} #{url}/#{repo}/issues/#{number}"
      
      github.get "#{base_url}/repos/#{bot_github_repo}/issues/" + issue_number, issue_message_generator(bot_github_repo, issue_number)
