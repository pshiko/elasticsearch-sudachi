/*
 * Copyright (c) 2023-2026 Works Applications Co., Ltd.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

@file:Suppress("PackageDirectoryMismatch")
@file:JvmName("OpenSearch3Extensions")

package com.worksap.nlp.search.aliases

import java.nio.file.Path

// OpenSearch 3.x compatibility: Environment.configFile() → Environment.configDir()
// In OpenSearch 2.x, the method was named configFile()
// In OpenSearch 3.x, it was renamed to configDir()
// This extension function provides backward compatibility

// Extension function to provide configFile() method for OpenSearch 3.x
// which only has configDir() method
@JvmName("configFileCompat") fun Environment.configFile(): Path = this.configDir()
