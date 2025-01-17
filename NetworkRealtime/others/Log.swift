//
//  Log.swift
//  NetworkRealtime
//
//  Created by Hailv on 2025/01/15.
//

import Logging

var log = {
  var _log = Logger(label: "network-speed")
  _log.logLevel = .debug
  return _log
}()
