extensions [palette]
;
; Variable
;
breed [ hunters hunter]
breed [ drugboats drugboat]
breed [tails tail]
breed [discs disc]
breed [ sanctuaries sanctuary]
breed[ place-holders place-holder]

globals [ tick-delta
          n
          i
          time-to-first-arrival
          time-to-first-see-list
          time-of-first-drugboat-detected
          time-of-stuck-drugboat
          rand-xcor
          rand-ycor
          rand-xcor2
          rand-ycor2
          sr_patches
          number-of-robots
          end_flag
          stuck_flag
          total_velocity_squared
          total_distance_traveled
          number-of-blind-hunters
         ]


hunters-own [
          velocity
           angular-velocity   ;; angular velocity of heading/yaw
           inputs             ;; input forces
           closest-turtle     ;; closest target
           impact-x
           impact-y
           impact-angle
           rand-x
           rand-y
           speed-w-noise
           turning-w-noise
           levy_time
           mass
           wait_ticks
           rand_turn
           step_count
           flight_count
           pre_flight_count
           step_time
           flight_time
           pre_flight_time
           closest-turtles
           closest-turtle2
           body_direct
           body_direct2
           coll_angle2
           detection_response_type
           fov-list-hunters
           fov-list-sanctuaries
           fov-list-green-hunters
           detect_sanctuaries?
           detect_hunters?
           detect_drugboats?
           fov-list-drugboats
           stuck_count
           idiosyncratic_val
           detect_step_count
           sleep_timer
           rand-head-distrbuance
           distance_traveled
           energy
           ricky_energy
           fov-list-patches
           sanctuary_detected_flag
           drugboat_caught_flag
;           body_v_x
;           body_v_y
           temp-turning-val
           random_switch-timer
          ]


drugboats-own [
           velocity
           angular-velocity   ;; angular velocity of heading/yaw
           inputs             ;; input forces
           closest-turtle     ;; closest target
           impact-x
           impact-y
           impact-angle
           rand-x
           rand-y
           rand-head-distrbuance
           speed-w-noise
           turning-w-noise
           levy_time
           mass
           wait_ticks
           rand_turn
           step_count
           flight_count
           pre_flight_count
           step_time
           flight_time
           pre_flight_time
           closest-turtles
           closest-turtle2
           body_direct
           body_direct2
           coll_angle2
           detection_response_type
           drugboat_caught_flag
           fov-list-drugboats
           fov-list-hunters
           fov-list-sanctuaries
           detect_sanctuaries?
           detect_drugboats?
           detect_hunters?
           stuck_count
           idiosyncratic_val
           furthest_ycor
           trapped_count
           detect_step_count
           fov-list-patches
          ]

patches-own [
            real-bearing-patch
          ]

discs-own [
            age
          ]




;;
;; Setup Procedures
;;
to setup
  clear-all
  random-seed seed-no


  set tick-delta 0.1 ; 10 ticks in one second

  let gr (range  -25 25 1)


  set rand-xcor one-of gr
  set rand-ycor one-of gr



  set time-to-first-see-list (list )

  ask patches
    [
      ifelse pycor = 25
      [
        set pcolor magenta
      ]
      [
        ifelse pycor = -25
        [
          set pcolor orange
        ]
        [
          set pcolor white
        ]
      ]
    ]


   add_sanctuary


  ;creates robots
  set number-of-robots (number-of-drugboats + number-of-hunters)

  set n number-of-robots

  set number-of-blind-hunters round number-of-hunters * (blind_percentage * .01)

  while [n > (number-of-hunters)]
  [
   make_drugboat
   set n (n - 1)
  ]

  while [n > (number-of-hunters - number-of-blind-hunters)]
  [
   make_hunter_blind
   set n (n - 1)
  ]

  while [n > 0]
  [
   make_hunter
   set n (n - 1)
  ]



   hunter_setup_strict

  ; adds extra "ghost" turtles that make adding and removing agents during simulation a bit easier
  create-place-holders 20
  [
    setxy max-pxcor max-pycor
    ht
  ]

  set-default-shape discs "ring"

  reset-ticks
end

;;
;; Runtime Procedures
;;
to go

  background_procedures ; for general functions like showing FOV

  ask drugboats
    [

      ; set whether or not the drugboat can detect specific types of agents
      set detect_sanctuaries? true
      set detect_drugboats? false
      set detect_hunters? true

      ifelse selected_algorithm_drugboat = "Manual Control"
      [
        drugboat_procedure_manual
      ]
      [
       drugboat_procedure
      ]

    ]

 ask hunters
    [
      ; set whether or not the hunter can detect specific types of agents
      set detect_sanctuaries? false

      ifelse can_hunters_see_each_other?
        [
          set detect_hunters? true
        ]
        [
          set detect_hunters? false

        ]
        ifelse shape = "blind-hunters"
        [
          set detect_drugboats? false
          hunter_procedure_blind
        ]
        [
          set detect_drugboats? true
          hunter_procedure
        ]


        if randomize_blindness?
        [
          if ticks mod random_switch-timer = 0 and length fov-list-drugboats = 0
          [
           ifelse shape = "blind-hunters"
           [
             set shape "circle 2"
           ]
           [
             set shape "blind-hunters"
           ]
          ]
        ]



      ]

  measure_results

  if end_flag = 1
  [
    ifelse loop_sim?
     [
       set seed-no (seed-no + 1)
       setup
     ]
     [
       stop
     ]

  ]

  tick-advance 1
end

to drugboat_procedure
  set_actuating_and_extra_variables ;does the procedure to set the speed and turning rate etc.
  do_sensing ; does the sensing to detect whatever the drugboat is set to detect

  ifelse length fov-list-sanctuaries > 0 ; if one or more sanctuaries are detected, it does what is in the first set of brackets (forward towards closest sanctuary)
    [
      set detection_response_type "forward"
      detection_response_procedure
      set color green
    ]
    [
      ifelse detect_step_count > 0 ; if value is positive, it performs whatever the detection response is (i.e. if set to 'turn-away-in-place" it will make sure it turns in place for a full second even if it detects something else
        [
          detection_response_procedure ; if agent is detected, it stops everything and executes the desired algorithm for one second

          set detect_step_count (detect_step_count - 1) ;counts down
          set color red
        ]
        [
         ifelse length fov-list-hunters > 0 ; if one or more hunters are detected, it reacts according to whatever the selected algorithm is (default is turn away in place
           [
             ifelse selected_algorithm_drugboat = "Milling"
             [
               set detection_response_type "mill-response"
             ]
             [
               ifelse selected_algorithm_drugboat = "Diffusing"
               [
                 set detection_response_type "diffuse-response"
               ]
               [
                ifelse selected_algorithm_drugboat = "Diffusing2"
                 [
                   set detection_response_type "diffuse-response2"
                 ]
                 [
                   set detection_response_type "turn-away-in-place"
                   choose_rand_turn
                 ]
                 ]
             ]
             set detect_step_count 1;(0.005 / tick-delta)
           ]
           [
             ifelse stuck_count > 100
               [
                set detection_response_type "90-in-place"
                choose_rand_turn
                set detect_step_count (1 / tick-delta)
                set stuck_count 0
               ]
               [
                ifelse ycor > 40
                [
                 select_alg_procedure2
                 set color yellow
                ]
                [
                  go_to_goal
                  set color orange
                ]
               ]
           ]
       ]
    ]


    ifelse ycor > furthest_ycor
    [
      set furthest_ycor ycor
      set trapped_count 0
    ]
    [
      set trapped_count trapped_count + 1
    ]

    if ycor > 35
    [
      set trapped_count 0
    ]

 update_agent_state; updates states of agents (i.e. position and heading)



end

to drugboat_procedure_manual ; buttons control what the inputs of the drugboat is, this is here to make the drugboat actually use those inputs to move
  set_actuating_and_extra_variables
  do_sensing

    ifelse ycor > furthest_ycor
    [
      set furthest_ycor ycor
      set trapped_count 0
    ]
    [
      set trapped_count trapped_count + 1
    ]

    if ycor > 35
    [
      set trapped_count 0
    ]

 update_agent_state; updates states of agents (i.e. position and heading)



end


to hunter_procedure
  set_actuating_and_extra_variables ;does the procedure to set the speed and turning rate etc.
  do_sensing ; does the sensing to detect whatever the hunter is set to detect


  ifelse length fov-list-drugboats > 0 ; if one or more drugboats are detected, it does what is in the first set of brackets (forward towards closest drugboat)
    [
      set detection_response_type "forward"
      detection_response_procedure
      set color green
    ]
    [
      ifelse detect_step_count > 0
        [
          detection_response_procedure ; if agent is detected, it stops everything and executes the desired algorithm for one second

          set detect_step_count (detect_step_count - 1) ;counts down
          set color blue
        ]
        [
          ifelse length fov-list-sanctuaries > 0 ; if value is positive, it performs whatever the detection response is (i.e. if set to 'turn-away-in-place" it will make sure it turns in place for a full second even if it detects something else
            [
              set detection_response_type "turn-away-in-place"
              choose_rand_turn
              set detect_step_count (0.25 / tick-delta)
            ]
            [
              ifelse length fov-list-hunters > 0 and sleep_timer < 0 ; if one or more hunters are detected, it reacts according to whatever the selected algorithm is (default is turn away in place. (sleep timer is added so it doesnt get stuck in infite loop of turning when face to face
                [
                  ifelse selected_algorithm_hunters = "Milling"
                  [
                    set detection_response_type "mill-response"
                    set detect_step_count (0.25 / tick-delta)
                  ]
                  [
                    ifelse selected_algorithm_hunters = "Diffusing"
                    [
                      set detection_response_type "diffuse-response"
                      set detect_step_count (0.25 / tick-delta)
                    ]
                    [
                      ifelse selected_algorithm_hunters = "Diffusing2"
                    [
                      set detection_response_type "diffuse-response2"
                      set detect_step_count (0.25 / tick-delta)
                    ]
                    [
                      set detection_response_type "180-in-place"
                      choose_rand_turn
                      set sleep_timer 20
                      set detect_step_count (1 / tick-delta)

                    ]
                    ]
                  ]

                ]
                [
                    ifelse stuck_count > 20
                    [
                     set detection_response_type "180-in-place"
                     choose_rand_turn
                     set detect_step_count (1 / tick-delta)
                     set stuck_count 0
                    ]
                    [
                      select_alg_procedure1
                      set color violet
                    ]

                    set sleep_timer (sleep_timer - 1)
                ]
            ]
       ]
    ]


 update_agent_state; updates states of agents (i.e. position and heading)

 if count drugboats > 0 and distance min-one-of drugboats [distance myself] < size
  [ set drugboat_caught_flag 1]

end

to hunter_procedure_blind
  set_actuating_and_extra_variables ;does the procedure to set the speed and turning rate etc.
  do_sensing ; does the sensing to detect whatever the hunter is set to detect


  ifelse length fov-list-drugboats > 0 ; if one or more drugboats are detected, it does what is in the first set of brackets (forward towards closest drugboat)
    [
      set detection_response_type "forward"
      detection_response_procedure
      set color green
    ]
    [
      ifelse detect_step_count > 0
        [
          detection_response_procedure ; if agent is detected, it stops everything and executes the desired algorithm for one second

          set detect_step_count (detect_step_count - 1) ;counts down
          set color blue
        ]
        [
          ifelse length fov-list-sanctuaries > 0 ; if value is positive, it performs whatever the detection response is (i.e. if set to 'turn-away-in-place" it will make sure it turns in place for a full second even if it detects something else
            [
              set detection_response_type "turn-away-in-place"
              choose_rand_turn
              set detect_step_count (0.25 / tick-delta)
            ]
            [
              ifelse length fov-list-hunters > 0 and sleep_timer < 0 ; if one or more hunters are detected, it reacts according to whatever the selected algorithm is (default is turn away in place. (sleep timer is added so it doesnt get stuck in infite loop of turning when face to face
                [
                  ifelse selected_algorithm_hunters_blind = "Milling"
                  [
                    set detection_response_type "mill-response"
                    set detect_step_count (0.25 / tick-delta)
                  ]
                  [
                    ifelse selected_algorithm_hunters_blind = "Diffusing"
                    [
                      set detection_response_type "diffuse-response"
                      set detect_step_count (0.25 / tick-delta)
                    ]
                    [
                    ifelse selected_algorithm_hunters_blind = "Diffusing2"
                    [
                      set detection_response_type "diffuse-response2"
                      set detect_step_count (0.25 / tick-delta)
                    ]
                    [
                      set detection_response_type "180-in-place"
                      choose_rand_turn
                      set sleep_timer 20
                      set detect_step_count (1 / tick-delta)
                      ]
                      ]


                  ]

                ]
                [
                    ifelse stuck_count > 20
                    [
                     set detection_response_type "180-in-place"
                     choose_rand_turn
                     set detect_step_count (1 / tick-delta)
                     set stuck_count 0
                    ]
                    [
                      select_alg_procedure_blind
                      set color violet
                    ]

                    set sleep_timer (sleep_timer - 1)
                ]
            ]
       ]
    ]


 update_agent_state; updates states of agents (i.e. position and heading)

 if count drugboats > 0 and distance min-one-of drugboats [distance myself] < size
  [ set drugboat_caught_flag 1]

end


to background_procedures
; clear-paint

ifelse paint_fov?
  [
    ask discs
      [
         set age age + 1
         if age = 1 [ die ]
       ]

    ask hunters
      [
         paint-patches-in-new-FOV
      ]

    ask drugboats
      [
         ifelse vision-cone-drugboats != 360
          [paint-patches-in-new-FOV]
          [
           hatch-discs 1
              [
                set size 2 * (vision-distance-drugboats * 10)
                set heading ([heading] of myself)
                palette:set-transparency 50
              ]
          ]
       ]
  ]
  [
    ask discs [die]
  ]

  ifelse draw_path?
  [
    ask drugboats [pd]
    ask hunters [pd]
  ]
  [
    ask drugboats [pu]
    ask hunters [pu]
  ]
end

to measure_results

      if count sanctuaries > 0
      [
        if time-to-first-arrival = 0
        [
          if count drugboats with [distance min-one-of sanctuaries [distance myself] <= (sanctuary-region-size / 2)] > 0
          [set time-to-first-arrival ticks]
        ]
       ]
        if time-of-first-drugboat-detected = 0
        [
          if count hunters with [drugboat_caught_flag = 1] > 0
          [set time-of-first-drugboat-detected ticks]
        ]

      if time-of-stuck-drugboat = 0
        [
          if count drugboats > 0 and max [trapped_count] of drugboats > 10000
           [
             set time-of-stuck-drugboat ticks
           ]
        ]


  set total_distance_traveled sum [distance_traveled] of hunters
  set total_velocity_squared sum [energy] of hunters

      if (time-to-first-arrival > 0) or  (time-of-first-drugboat-detected > 0) or (time-of-stuck-drugboat  > 0)
      [set end_flag 1]
end




to select_alg_procedure1
  if selected_algorithm_hunters = "Milling"
  [mill]

  if selected_algorithm_hunters = "Diffusing"
  [dispersal]

  if selected_algorithm_hunters = "Diffusing2"
  [dispersal2]

  if selected_algorithm_hunters = "Standard Random"
  [standard_random_walk]

  if selected_algorithm_hunters = "Levy"
  [real_levy]

  if selected_algorithm_hunters = "Lie and Wait"
  [lie-and-wait]

  if selected_algorithm_hunters = "Straight"
  [straight]

  if selected_algorithm_hunters = "Spiral"
  [spiral]

  if selected_algorithm_hunters = "Custom"
  [custom_alg]

end

to select_alg_procedure_blind
  if selected_algorithm_hunters_blind = "Milling"
  [mill]

  if selected_algorithm_hunters_blind = "Diffusing"
  [dispersal]

  if selected_algorithm_hunters = "Diffusing2"
  [dispersal2]

  if selected_algorithm_hunters_blind = "Standard Random"
  [standard_random_walk]

  if selected_algorithm_hunters_blind = "Levy"
  [real_levy]

  if selected_algorithm_hunters_blind = "Lie and Wait"
  [lie-and-wait]

  if selected_algorithm_hunters_blind = "Straight"
  [straight]

  if selected_algorithm_hunters_blind = "Spiral"
  [spiral]

  if selected_algorithm_hunters_blind = "Custom"
  [custom_alg]

end

to select_alg_procedure2
  if selected_algorithm_hunters = "Milling"
  [mill]

  if selected_algorithm_hunters = "Diffusing"
  [dispersal]

  if selected_algorithm_hunters = "Diffusing2"
  [dispersal2]

  if selected_algorithm_hunters = "Standard Random"
  [standard_random_walk]

  if selected_algorithm_hunters = "Levy"
  [real_levy]

  if selected_algorithm_hunters = "Lie and Wait"
  [lie-and-wait]

  if selected_algorithm_hunters = "Straight"
  [straight]

end


to straight
  set inputs (list speed-w-noise 90 0)
end

to lie-and-wait
      set inputs (list 0 90 turning-w-noise)
end

to go_to_goal
   let target_bearing (towards sanctuary 0) - heading

      ifelse target_bearing < -180
        [
          set target_bearing target_bearing + 360
         ]
        [
          ifelse target_bearing > 180
          [set target_bearing target_bearing - 360]
          [set target_bearing target_bearing]
        ]

      ifelse (target_bearing) > 0
        [set inputs (list (speed-w-noise) 90 turning-w-noise)]
        [set inputs (list (speed-w-noise) 90 (- turning-w-noise))]

end



to mill  ;; control rule for if nothing is detected (for milling)
  set_actuating_and_extra_variables
  do_sensing

   set inputs (list (1 * speed-w-noise) 90 ( 1  * turning-w-noise))
end

to dispersal ; control rule for if nothing is detected (for diffusion)
  set_actuating_and_extra_variables
  do_sensing

  set inputs (list (0 * speed-w-noise) 90 ( 1  * turning-w-noise))

end

to dispersal2 ; control rule for if nothing is detected (for diffusion)
  set_actuating_and_extra_variables
  do_sensing

  set inputs (list (1 * speed-w-noise) 90 ( 1  * turning-w-noise))

end

to spiral
 ifelse temp-turning-val > 0 ; while step count is less than the set step_length, it should either be turning in place or going straight
  [

    set temp-turning-val (temp-turning-val - 0.1)
    set inputs (list speed-w-noise 90 temp-turning-val)

  ]
  [
     set temp-turning-val 60
  ]
end


to custom_alg
 ;design your own algorithm of what the hunters should be doing to search the environment (before they see the drugboat)

 ;example
 ifelse ticks mod 300 < 150 ; every 150 ticks, do what is in first set of brackets, else do what is in second set
  [
    set inputs (list speed-w-noise 90 0) ; move straight forward
  ]
  [
    set inputs (list speed-w-noise 270 0) ; move straight backwards
  ]
end



to standard_random_walk ;

  ifelse step_count < (step_length_fixed + idiosyncratic_val) ; while step count is less than the set step_length, it should either be turning in place or going straight
  [

    ifelse step_count < (1 / tick-delta) ; for the first 10 ticks of the "step", turn in place at a rate of rand_turn
     [
       set inputs (list (0) 90 rand_turn)
     ]
     [
      set inputs (list speed-w-noise 90 0) ; if nothing is detected, goes straight forward at a speed of speed-w-noise

     ]

    set step_count step_count + 1 ;counts up
  ]
  [
     choose_rand_turn ; at the end of the step, choose random turning rate
     set step_count 0 ; reset turning rate to zero
  ]

end


to real_levy  ;; classic levy that chooses direction at beginning of step and moves straight in that line. Step lengths are chosen from levy distribution

  ifelse step_count < step_time; while step count is less than the the randomly chosen step_length, it should either be turning in place or going straight
  [

    ifelse step_count < (1 / tick-delta) ; for the first 10 ticks of the "step", turn in place at a rate of rand_turn
     [
       set color blue
        set inputs (list (0) 90 rand_turn)
     ]
     [
       set color red
       set inputs (list speed-w-noise 90 0) ; if nothing is detected, goes straight forward at a speed of speed-w-noise
     ]

    set step_count step_count + 1 ;increment step count
  ]
  [
      ; at the end of the step, choose a new step length from levy distribution and choose random turning rate
       set step_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
       while [step_time > round (max_levy_time / tick-delta)]
         [set step_time round (100 * (1 / (random-gamma 0.5 (c / 2 ))))]

       choose_rand_turn
       set step_count 0
  ]
end



;
;
;-------------- Nested functions and Setup Procedures below--------------
;
;

to detection_response_procedure
  let target (max-one-of place-holders [distance myself]);
  let hostile (max-one-of place-holders [distance myself])

  ifelse member? self hunters
   [
     set target one-of drugboats
   ]
   [
     set target min-one-of sanctuaries [distance myself]
     set hostile min-one-of hunters [distance myself]
   ]

  if detection_response_type = "turn-away-in-place"
    [
      let hostile_bearing towards hostile - heading

      ifelse hostile_bearing < -180
        [
          set hostile_bearing hostile_bearing + 360
         ]
        [
          ifelse hostile_bearing > 180
          [set hostile_bearing hostile_bearing - 360]
          [set hostile_bearing hostile_bearing]
        ]

      ifelse (hostile_bearing) > 0
        [set inputs (list (speed-w-noise) 90(- turning-w-noise))]
        [set inputs (list (speed-w-noise) 90( turning-w-noise))]
     ]

  if detection_response_type = "turn-away-in-place-sometimes"
    [
      let hostile_bearing towards hostile - heading

      ifelse hostile_bearing < -180
        [
          set hostile_bearing hostile_bearing + 360
         ]
        [
          ifelse hostile_bearing > 180
          [set hostile_bearing hostile_bearing - 360]
          [set hostile_bearing hostile_bearing]
        ]

      if (hostile_bearing) > -30 and (hostile_bearing) < 30
      [
        ifelse (hostile_bearing) > 0
        [set inputs (list (speed-w-noise) 90(- turning-w-noise))]
        [set inputs (list (speed-w-noise) 90( turning-w-noise))]
      ]
     ]


    if detection_response_type = "reverse-and-turn"
    [
      set inputs (list (- speed-w-noise) 90 90)
    ]

    if detection_response_type = "reverse"
    [
      ifelse random 2 < 1
      [
        set inputs (list ( speed-w-noise) 315 0)
      ]
      [
        set inputs (list ( speed-w-noise) 225 0)
      ]
    ]


    if detection_response_type = "diffuse-response"
    [
      set inputs (list (- speed-w-noise) 90 0)
    ]

    if detection_response_type = "diffuse-response2"
    [
      set inputs (list (1 * speed-w-noise) 90 ( 2 * turning-w-noise))
    ]

    if detection_response_type = "mill-response"
    [
      set inputs (list (speed-w-noise) 90 (- turning-w-noise))
    ]

    if detection_response_type = "90-in-place"
    [
      set inputs (list (0) 90 90)
    ]

    if detection_response_type = "180-in-place"
    [
      set inputs (list (0) 90 180)
    ]

    if detection_response_type = "stop"
      [
        set inputs (list (0) 90 0)
      ]

    if detection_response_type = "slow-reverse"
      [
        set inputs (list (speed-w-noise * 0.25) 270 0)
      ]

    if detection_response_type = "forward"
    [
      let target_bearing towards target - heading

      ifelse target_bearing < -180
        [
          set target_bearing target_bearing + 360
         ]
        [
          ifelse target_bearing > 180
          [set target_bearing target_bearing - 360]
          [set target_bearing target_bearing]
        ]

      ifelse (target_bearing) > 0
        [set inputs (list (speed-w-noise) 90 turning-w-noise)]
        [set inputs (list (speed-w-noise) 90 (- turning-w-noise))]
     ]

     if detection_response_type = "center-in-place"
       [
         let target_bearing towards target - heading

         ifelse target_bearing < -180
           [
             set target_bearing target_bearing + 360
            ]
           [
             ifelse target_bearing > 180
             [set target_bearing target_bearing - 360]
             [set target_bearing target_bearing]
           ]

         ifelse (target_bearing) > 0
           [set inputs (list (0) 90 turning-w-noise)]
           [set inputs (list (0) 90 (- turning-w-noise))]
        ]

      if detection_response_type = "rotate-around"
           [
             let target_bearing towards target - heading

             ifelse target_bearing < -180
               [
                 set target_bearing target_bearing + 360
                ]
               [
                 ifelse target_bearing > 180
                 [set target_bearing target_bearing - 360]
                 [set target_bearing target_bearing]
               ]

             ifelse (target_bearing) > 0
               [set inputs (list (speed-w-noise) 0 turning-w-noise)]
               [set inputs (list (speed-w-noise) 0 (- turning-w-noise))]
            ]
end

to choose_rand_turn
  let turning-rate-val 0
  if member? self hunters
    [
      set turning-rate-val turning-rate-rw
    ]

  if distribution_for_direction = "uniform"
  [set rand_turn (- turning-rate-val) + (random (2 * turning-rate-val + 1)) ]

  if distribution_for_direction = "gaussian"
  [ set rand_turn round (random-normal 0 (turning-rate-val / 3))]

  if distribution_for_direction = "triangle"
  [set rand_turn (random turning-rate-val) - (random turning-rate-val) ]
end


to set_actuating_and_extra_variables
  if ticks mod 1 = 0
  [
    set rand-x random-normal 0 state-disturbance_xy
    set rand-y random-normal 0 state-disturbance_xy
    set rand-head-distrbuance random-normal 0 state-disturbance_head
  ]

  ifelse member? self hunters
  [
    set speed-w-noise random-normal (speed1 * 10) (noise-actuating-speed)
    set turning-w-noise random-normal (turning-rate1) noise-actuating-turning
  ]
  [
    set speed-w-noise random-normal (speed-drugboats * 10) (noise-actuating-speed  * 0.1)
    set turning-w-noise random-normal (turning-rate-drugboats) noise-actuating-turning
  ]
end

to do_sensing
  ifelse detect_sanctuaries?
    [find-sanctuaries-in-FOV]
    [set fov-list-sanctuaries (list)]

    ifelse detect_drugboats?
    [find-drugboats-in-FOV]
    [set fov-list-drugboats (list)]

  ifelse detect_hunters?
    [find-hunters-in-FOV]
    [set fov-list-hunters (list)]

end

to update_agent_state
  agent_dynamics

  if member? self hunters
  [
    set distance_traveled (distance_traveled + .10 * (item 0 inputs * tick-delta))
    set energy (energy +  (((.10 * item 0 inputs) ^ 2 + (item 1 inputs * pi / 180) ^ 2) * tick-delta) )
  ]


   do_collisions


  let nxcor xcor + ( item 0 velocity * tick-delta  ) + (impact-x * tick-delta  ) + (rand-x * tick-delta  )
  let nycor ycor + ( item 1 velocity * tick-delta  ) + (impact-y * tick-delta  ) + (rand-y * tick-delta  )


  ;; makes sure agents don't go through edge (if the calculated next position is more than the boundary, it just forces the agent to stay in place)
  if nxcor > max-pxcor or nxcor < min-pxcor
   [
     set nxcor xcor
     set nycor ycor
     set stuck_count stuck_count + 1
   ]

  ifelse protected_spawn? and member? self hunters ; if the switch is on, it makes the orange line inpassable using same method above
  [
    if nycor > max-pycor or nycor < -25
    [ set nycor ycor
      set nxcor xcor
      set stuck_count stuck_count + 1
    ]
  ]
  [
    if nycor > max-pycor or nycor < min-pycor
    [ set nycor ycor
      set nxcor xcor
      set stuck_count stuck_count + 1]
  ]

  setxy nxcor nycor

  let nheading heading + (angular-velocity * tick-delta  ) + (impact-angle * tick-delta ) + (rand-head-distrbuance * tick-delta)
  set heading nheading
end



to add_hunter
  ask place-holder ((count sanctuaries + count drugboats   + count hunters))
  [  set breed hunters
      st
      setxy 0.3 0
      set sr_patches patches with [(distancexy 0 0 < (number-of-robots * ([size] of hunter (count sanctuaries + count drugboats  )) / pi)) and pxcor != 0 and pycor != 0]


      move-to one-of sr_patches with [(not any? other turtles in-radius ([size] of hunter (count sanctuaries + count drugboats  )))]
      setxy (xcor + .01) (ycor + .01)

      set velocity [ 0 0 ]
      set angular-velocity 0
      set inputs [0 0 0]



      set shape "circle 2"
      set color red
      set size 2 ; sets size to 0.1m

      set mass size

     set levy_time 200
     set color red
    ]

    set number-of-hunters (number-of-hunters + 1)
end

to remove_hunter
ask hunter (count sanctuaries + count drugboats   + count hunters - 1)
  [
    set breed place-holders
    ht
  ]
  set number-of-hunters (number-of-hunters - 1)

end

to add_sanctuary
  create-sanctuaries number-of-sanctuaries
  [
    set shape "sanctuary"


    let gr (range  (min-pxcor + sanctuary-region-size) (max-pxcor - sanctuary-region-size) 1)
    setxy (one-of gr) (max-pycor)


    set size sanctuary-region-size
    set color green
    stamp
    set size 1
    set color green
  ]
end

to make_hunter
  create-hunters 1
    [
      set velocity [ 0 0]
      set angular-velocity 0
      set inputs [0 0 0]
      set size 2 ;2 meter diameter

      set fov-list-sanctuaries (list )
      set fov-list-hunters (list )
      set fov-list-drugboats (list )


      place_hunters


      set shape "circle 2"
      set color red
      set mass size

      set levy_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
      while [levy_time > (max_levy_time / tick-delta)]
      [set levy_time round (100 * (1 / (random-gamma 0.5 (.5))))]
      choose_rand_turn
      set idiosyncratic_val round (random-normal 0 10)

      set color red

     set coll_angle2 0
     set detect_sanctuaries? false
     set detect_drugboats? false
     set detect_hunters? false

    set detection_response_type "turn-away-in-place"

    set random_switch-timer round random-normal 200 50
    ]
end

to make_hunter_blind
  create-hunters 1
    [
      set velocity [ 0 0]
      set angular-velocity 0
      set inputs [0 0 0]
      set size 2 ;2 meter diameter

      set fov-list-sanctuaries (list )
      set fov-list-hunters (list )
      set fov-list-drugboats (list )


      place_hunters


      set shape "blind-hunters"
      set color red
      set mass size

      set levy_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
      while [levy_time > (max_levy_time / tick-delta)]
      [set levy_time round (100 * (1 / (random-gamma 0.5 (.5))))]
      choose_rand_turn
      set idiosyncratic_val round (random-normal 0 10)

      set color blue

     set coll_angle2 0
     set detect_sanctuaries? false
     set detect_drugboats? false
     set detect_hunters? false

    set detection_response_type "turn-away-in-place"
    set random_switch-timer round random-normal 200 50
    ]
end

to make_drugboat
  create-drugboats 1
    [
      set velocity [0 0]
      set angular-velocity 0
      set inputs [0 0 0]
      set size 2; 0.2m diameter

      set fov-list-sanctuaries (list )
      set fov-list-hunters (list )
      set fov-list-drugboats (list )

      set furthest_ycor min-pycor

      set sr_patches patches with [pycor < -25 and pxcor != 0]
      move-to one-of sr_patches with [(not any? other turtles in-radius ([size] of drugboat (count sanctuaries)))]
      setxy (xcor + .01) (ycor + .01)

      ifelse selected_algorithm_drugboat = "Manual Control"
       [
        set heading 0
       ]
       [
        set heading towardsxy 0 0
       ]


      set shape "runner"
      set color red
      set mass size


     set levy_time round (100 * (1 / (random-gamma 0.5 (c / 2  ))))
     while [levy_time > (max_levy_time / tick-delta)]
     [set levy_time round (100 * (1 / (random-gamma 0.5 (.5  ))))]
     choose_rand_turn
     set idiosyncratic_val round (random-normal 0 10)

     set color red
     set coll_angle2 0

      set detect_sanctuaries? false
      set detect_drugboats? false
      set detect_hunters? false

      set detection_response_type "turn-away-in-place"
    ]
end

to place_hunters; defines region and/or orientation of where the hunters should start
  if Hunter_setup = "Random"
   [
       let tycor one-of (range (-25) (25) 0.01)
       let txcor one-of (range (-30) (30) 0.01)

       setxy txcor tycor
   ]

  if Hunter_setup = "Center Band"
   [
     let tycor one-of (range (-5) (5) 0.01)
     let txcor one-of (range (-30) (30) 0.01)

     setxy txcor tycor
   ]

  if Hunter_setup = "Barrier"
   [
     let tycor one-of (range (-3) (3) 0.01)
     let txcor one-of (range (-30) (30) 0.01)

     setxy txcor tycor

     ifelse  heading mod 2 = 0
       [
         set heading 90       ]
       [
         set heading 270
       ]
   ]


  if Hunter_setup = "Inverted V"
   [
     let txcor one-of (range (-30) (30) 0.01)
     let selected_xcor txcor
     ifelse selected_xcor > 0
        [setxy selected_xcor (25 - (1.73333 * selected_xcor))]
        [setxy selected_xcor (25 + (1.73333 * selected_xcor))]


     setxy (xcor + random-normal 0 0.5) (ycor + random-normal 0 0.5)

     ifelse  heading mod 2 = 0
       [
         set heading towardsxy 0 30;random-normal 90 10
       ]
       [
         set heading 180 + towardsxy 0 30;random-normal 270 10
       ]
   ]

  if Hunter_setup = "Circle - Center"
   [
    set sr_patches patches with [(distancexy 0 0 < (sqrt(number-of-hunters) * ([size] of hunter (count sanctuaries  + count drugboats)) * (1) ) + 1) and pxcor != 0 and pycor != 0]
    move-to one-of sr_patches with [(not any? other turtles in-radius ([size] of hunter (count sanctuaries + count drugboats)))]
     setxy (xcor + 0.01) (ycor + 0.01)
   ]

  if Hunter_setup = "Circle - Random"
   [
    set sr_patches patches with [(distancexy rand-xcor rand-ycor < (sqrt(number-of-hunters) * ([size] of hunter (count sanctuaries + count drugboats)) * (1) ) + 1) and pxcor != 0 and pycor != 0]
    move-to one-of sr_patches with [(not any? other turtles in-radius ([size] of hunter (count sanctuaries + count drugboats)))]
     setxy (xcor + 0.01) (ycor + 0.01)
   ]


  if Hunter_setup = "Circle - Center - Facing Out"
   [
    set sr_patches patches with [(distancexy 0 0 < (sqrt(number-of-hunters) * ([size] of hunter (count sanctuaries + count drugboats)) * (1) ) + 1) and pxcor != 0 and pycor != 0]
    move-to one-of sr_patches with [(not any? other turtles in-radius ([size] of hunter (count sanctuaries + count drugboats)))]
     setxy (xcor + 0.01) (ycor + 0.01)

    set heading 180 + towardsxy 0 0
   ]

  if Hunter_setup = "Custom - Region" ; design your own setup by defining the region they should start in
   [
    ; use examples above to find a way to set them up however you like
   ]

end


to hunter_setup_strict; if you want to more precisely place the hunters (i.e. hunter 2 needs to be at position x, etc.)
  if Hunter_setup = "Imperfect Picket"
   [
     let j number-of-sanctuaries + number-of-drugboats
     let jc number-of-sanctuaries + number-of-drugboats

     while [j < number-of-sanctuaries + number-of-drugboats + number-of-hunters]
     [ask hunter (j )
       [
         setxy (((j - jc) * (61 / number-of-hunters)) - (max-pxcor - (61 / number-of-hunters) / 2)) (0)

        if xcor > min-pxcor and xcor < max-pxcor
        [
          setxy (xcor + random-normal 0 0.5) (ycor + random-normal 0 0.5)
          set heading (180 + random-normal 0 10)
        ]

         setxy xcor (ycor + 0.01)
       ]
       set j j + 1
     ]
   ]

  if Hunter_setup = "Perfect Picket"
   [
     let j number-of-sanctuaries + number-of-drugboats
     let jc number-of-sanctuaries + number-of-drugboats

     while [j < number-of-sanctuaries + number-of-drugboats + number-of-hunters]
     [ask hunter (j )
       [
         setxy (((j - jc) * (61 / number-of-hunters)) - 30) (0)

        set heading 180

         setxy xcor (ycor + 0.01)
       ]

       set j j + 1
     ]
   ]


  if Hunter_setup = "Perfect Circle"
   [
      let irr1  (07 * ([size] of hunter (number-of-sanctuaries + number-of-drugboats)) / (2 * pi) ) + 1
      let irr2  (24 * ([size] of hunter (number-of-sanctuaries + number-of-drugboats)) / (2 * pi) ) + 1
      let j number-of-sanctuaries + number-of-drugboats
      let heading_num1 360 / number-of-blind-hunters 
      let heading_num2 360 / (number-of-hunters - number-of-blind-hunters)
      let random-rotation random 90

      while [j < number-of-sanctuaries + number-of-drugboats + number-of-blind-hunters]
      [ask hunter (j)
        [
          setxy (irr1 * -1 * cos(j * heading_num1)) (irr1 * sin(j * heading_num1))       set heading 180 + towardsxy 0 0
        ]

        set j j + 1
      ]

      while [j < number-of-sanctuaries + number-of-drugboats + number-of-hunters]
      [ask hunter (j)
        [
          setxy (irr2 * -1 * cos(j * heading_num2)) (irr2 * sin(j * heading_num2))       set heading 180 + towardsxy 0 0
        ]

        set j j + 1
      ]


   ]



  if Hunter_setup = "Custom - Precise"; specify exactly where you want each robot to be placed to create shapes and better formations
   [
     ; use examples above to find a way to set them up however you like
   ]
end


to clear-paint
ask patches
    [
      ifelse pycor = 25
      [
        set pcolor magenta
      ]
      [
        ifelse pycor = -25
        [
          set pcolor orange
        ]
        [
          set pcolor white
        ]
      ]
    ]
end


to agent_dynamics
  ; Reminder, each patch represents 0.1m, these values below are in terms of patches (i.e. 0.25 patches = 0.025m = 2.5cm)

  let body_v_x (item 0 inputs) * sin (item 1 inputs) ; forward speed
  let body_v_y (item 0 inputs) * -1 * cos( item 1 inputs) ; transversal speed
  let theta_dot (item 2 inputs) ; turning rate
  ; above is altered due to netlogo's definition of 0 deg (or 0 rad). heading of 0 is pointing straight north rather than east.
  ; and heading of 90 deg is east rather than north (i.e. increasing angle means going clockwise rather than counter-clockwise)

  let resultant_v sqrt(body_v_x ^ 2 + body_v_y ^ 2)

  ifelse body_v_x = 0 and body_v_y = 0 ; checks to make sure atan can be used (if the first argument is zero it sometimes creates an error)
  [set body_direct heading]
  [set body_direct atan body_v_y body_v_x]

                                                          ; In traditional coordinates
  let v_x resultant_v * sin(- body_direct + heading)   ; set v_x resultant_v * cos(- body_direct + heading)
  let v_y resultant_v * cos(- body_direct + heading )  ; set v_y resultant_v * sin(- body_direct + heading )
   ; above is altered due to netlogo's definition of 0 deg (or 0 rad). heading of 0 is pointing straight north rather than east.
  ; and heading of 90 deg is east rather than north (i.e. increasing angle means going clockwise rather than counter-clockwise)


  set velocity (list (v_x) (v_y) 0)
  set angular-velocity (theta_dot)
end



to do_collisions
if count other turtles with [breed != sanctuaries and breed != discs] > 0
      [
        let closest-turtle1 (max-one-of place-holders [distance myself])

        if  count hunters > 1
        [
          ifelse count hunters > 3
          [
            set closest-turtles (min-n-of 2 other turtles with [breed != sanctuaries and breed != discs] [distance myself])

            set closest-turtle1 (min-one-of closest-turtles [distance myself])
            set closest-turtle2 (max-one-of closest-turtles [distance myself])
          ]
          [
            set closest-turtle1 (min-one-of other turtles with [breed != sanctuaries and breed != discs] [distance myself])
          ]
        ]


        set closest-turtle closest-turtle1

        ifelse (distance closest-turtle ) < (size + ([size] of closest-turtle)) / 2
           [
              let xdiff item 0 target-diff
              let ydiff item 1 target-diff

              if closest-turtle2 != 0
              [
                let xdiff2 item 0 target-diff2
                let ydiff2 item 1 target-diff2
                set coll_angle2 (rel-bearing2 - (body_direct2))
                ifelse coll_angle2 < -180
                  [
                    set coll_angle2 coll_angle2 + 360
                   ]
                  [
                    ifelse coll_angle2 > 180
                    [set coll_angle2 coll_angle2 - 360]
                    [set coll_angle2 coll_angle2]
                  ]
              ]
              set body_direct2 (360 - body_direct)
              let coll_angle (body_direct2 - rel-bearing); - (90 - heading)); - (body_direct2))
;              let coll_angle (heading + body_direct2) - (rel-bearing)


              if body_direct2 > 180
              [
                set body_direct2 (body_direct2 - 360)
              ]

              ifelse coll_angle < -180
              [
                set coll_angle coll_angle + 360
               ]
              [
                ifelse coll_angle > 180
                [set coll_angle coll_angle - 360]
                [set coll_angle coll_angle]
              ]


              ifelse abs(coll_angle) < 90
              [
                set impact-x  (-1 * item 0 velocity)
                set impact-y  (-1 * item 1 velocity)

                set stuck_count stuck_count + 1
              ]
              [
               set impact-x 0
               set impact-y 0
               set impact-angle 0
              ]

              if closest-turtle2 != 0
              [
                if (distance closest-turtle2 ) < (size + ([size] of closest-turtle)) / 2
                [
                   if abs(coll_angle2) < 90
                   [
                     set impact-x  (-1 * item 0 velocity)
                     set impact-y  (-1 * item 1 velocity)
                   ]
                ]
              ]

                ]
          [
            set wait_ticks 0
            set impact-angle 0
            set impact-x 0
            set impact-y 0
          ]
      ]
end

to find-drugboats-in-FOV
  let vision-dd 0
  let vision-cc 0
  let real-bearing 0

  ifelse member? self hunters
    [
      set vision-dd vision-distance
      set vision-cc vision-cone
    ]
    [
      set vision-dd vision-distance-drugboats
    set vision-cc vision-cone-drugboats
    ]
  set fov-list-drugboats (list )
  set i (count sanctuaries)

  while [i < (count sanctuaries + count drugboats)]
    [
      if self != drugboat ((i )  )
        [
          let sub-heading towards drugboat (i ) - heading
          set real-bearing sub-heading

          if sub-heading < 0
            [set real-bearing sub-heading + 360]

          if sub-heading > 180
            [set real-bearing sub-heading - 360]

          if real-bearing > 180
            [set real-bearing real-bearing - 360]

          if (abs(real-bearing) < ((vision-cc / 2))) and (distance-nowrap (drugboat (i )) < (vision-dd * 10));
           [
             set fov-list-drugboats fput (drugboat (i)) fov-list-drugboats
           ]
          ]
     set i (i + 1)
    ]

end


to find-hunters-in-FOV
  let vision-dd 0
  let vision-cc 0
  let real-bearing 0

  ifelse member? self hunters
    [
      set vision-dd vision-distance
      set vision-cc vision-cone
    ]
    [
      set vision-dd vision-distance-drugboats
    set vision-cc vision-cone-drugboats
    ]

  set fov-list-hunters (list )
  set i (count sanctuaries  + count drugboats)

  while [i < (count sanctuaries + count drugboats   + count hunters)]
    [
      if self != hunter ((i )  )
        [
          let sub-heading towards hunter (i ) - heading
          set real-bearing sub-heading

          if sub-heading < 0
            [set real-bearing sub-heading + 360]

          if sub-heading > 180
            [set real-bearing sub-heading - 360]

          if real-bearing > 180
            [set real-bearing real-bearing - 360]


          if (abs(real-bearing) < ((vision-cc / 2))) and (distance-nowrap (hunter (i )) < (vision-dd * 10));
           [
             set fov-list-hunters fput (hunter (i)) fov-list-hunters
              if [sanctuary_detected_flag] of hunter (i) = 1
              [
               set fov-list-green-hunters fput (hunter (i)) fov-list-green-hunters
              ]
           ]
        ]
     set i (i + 1)
    ]
end



to find-sanctuaries-in-FOV
  let vision-dd 0
  let vision-cc 0
  let real-bearing 0

  ifelse member? self hunters
    [
      set vision-dd vision-distance
      set vision-cc vision-cone
    ]
    [
      set vision-dd vision-distance-drugboats
    set vision-cc vision-cone-drugboats
    ]

  set fov-list-sanctuaries (list )
  set i 0

  while [i < (count sanctuaries)]
    [
          let sub-heading towards sanctuary (i ) - heading
          set real-bearing sub-heading

          if sub-heading < 0
            [set real-bearing sub-heading + 360]

          if sub-heading > 180
            [set real-bearing sub-heading - 360]

          if real-bearing > 180
            [set real-bearing real-bearing - 360]


          if (abs(real-bearing) < ((vision-cc / 2))) and (distance-nowrap (sanctuary (i )) < (vision-dd * 10));
           [
             set fov-list-sanctuaries fput (sanctuary (i)) fov-list-sanctuaries
           ]
     set i (i + 1)
    ]
end


to paint-patches-in-new-FOV

  let vision-dd 0
  let vision-cc 0
  ifelse member? self hunters
    [
      set vision-dd vision-distance
      set vision-cc vision-cone
    ]
    [
      set vision-dd vision-distance-drugboats
    set vision-cc vision-cone-drugboats
    ]



  set fov-list-patches (list )
  set i 0

  set fov-list-patches patches in-cone (vision-dd * 10) (vision-cc) with [(distancexy-nowrap ([xcor] of myself) ([ycor] of myself) <= (vision-dd * 10))  and pcolor != black]


  ask fov-list-patches
  [
      ifelse towards myself  > 180
      [
        let sub-heading (towards myself - 180) - [heading] of myself
        set real-bearing-patch sub-heading
        if sub-heading < 0
          [set real-bearing-patch sub-heading + 360]

        if sub-heading > 180
          [set real-bearing-patch sub-heading - 360]

        if real-bearing-patch > 180
          [set real-bearing-patch real-bearing-patch - 360]
      ]
      [
        let sub-heading (towards myself + 180) - [heading] of myself
        set real-bearing-patch sub-heading

        if sub-heading < 0
          [set real-bearing-patch sub-heading + 360]

        if sub-heading > 180
          [set real-bearing-patch sub-heading - 360]

        if real-bearing-patch > 180
          [set real-bearing-patch real-bearing-patch - 360]
      ]




     if (real-bearing-patch < ((vision-cc / 2)) and real-bearing-patch > ((-1 * (vision-cc / 2))))
     [
      ifelse member? myself hunters
      [set pcolor orange]
      [set pcolor yellow]
     ]
  ]

end






to-report target-diff  ;; robot reporter
     report
    (   map
        [ [a q] -> a - q]
        (list
          [xcor] of closest-turtle
          [ycor] of closest-turtle)
        (list
          xcor
          ycor))

end

to-report target-diff2  ;; robot reporter
     report
    (   map
        [ [a q] -> a - q]
        (list
          [xcor] of closest-turtle2
          [ycor] of closest-turtle2)
        (list
          xcor
          ycor))
end


to-report rel-bearing
  let xdiff item 0 target-diff
  let ydiff item 1 target-diff
  let angle 0

  let cart-heading (90 - heading)

  ifelse cart-heading < 0
    [set cart-heading cart-heading + 360]
    [set cart-heading cart-heading]

  ifelse cart-heading > 180
    [set cart-heading cart-heading - 360]
    [set cart-heading cart-heading]

  set angle (atan ydiff xdiff)


  let bearing cart-heading - angle
  if bearing < -180
    [set bearing bearing + 360]
  report( bearing )
end

to-report rel-bearing2
  let xdiff2 item 0 target-diff2
  let ydiff2 item 1 target-diff2
  let angle2 0

  let cart-heading2 (90 - heading)

  ifelse cart-heading2 < 0
    [set cart-heading2 cart-heading2 + 360]
    [set cart-heading2 cart-heading2]

  ifelse cart-heading2 > 180
    [set cart-heading2 cart-heading2 - 360]
    [set cart-heading2 cart-heading2]

  if xdiff2 != 0 and ydiff2 != 0
    [set angle2 (atan ydiff2 xdiff2)]


  let bearing2 cart-heading2 - angle2
  if bearing2 < -180
    [set bearing2 bearing2 + 360]
  report( bearing2 )
end
@#$#@#$#@
GRAPHICS-WINDOW
498
74
902
479
-1
-1
6.5
1
10
1
1
1
0
0
0
1
-30
30
-30
30
1
1
1
ticks
10.0

SLIDER
191
30
283
63
seed-no
seed-no
1
50
12.0
1
1
NIL
HORIZONTAL

SLIDER
18
329
190
362
vision-distance
vision-distance
0
1.1
1.1
0.1
1
m
HORIZONTAL

SLIDER
16
366
188
399
vision-cone
vision-cone
0
50
50.0
5
1
deg
HORIZONTAL

SLIDER
15
406
194
439
speed1
speed1
0
0.3
0.2
0.05
1
m/s
HORIZONTAL

SLIDER
13
442
193
475
turning-rate1
turning-rate1
0
360
25.0
5
1
deg/s
HORIZONTAL

BUTTON
22
22
102
62
NIL
setup
NIL
1
T
OBSERVER
NIL
P
NIL
NIL
1

BUTTON
110
22
177
62
NIL
go
T
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
10
485
113
520
NIL
add_hunter
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
9
525
135
560
NIL
remove_hunter
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
251
112
371
145
paint_fov?
paint_fov?
1
1
-1000

SWITCH
251
149
372
182
draw_path?
draw_path?
1
1
-1000

BUTTON
372
149
475
182
clear-paths
clear-drawing
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
372
109
472
142
NIL
clear-paint
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
20
289
205
322
number-of-hunters
number-of-hunters
0
30
18.0
1
1
NIL
HORIZONTAL

SLIDER
1760
462
1933
495
c
c
0
5
0.5
.25
1
NIL
HORIZONTAL

TEXTBOX
1770
442
1985
468
For Levy Distribution
11
0.0
1

TEXTBOX
260
96
475
122
Turn off to speed up sim\n
11
0.0
1

TEXTBOX
2194
1245
2409
1271
NIL
11
0.0
1

SLIDER
1762
360
1955
393
number-of-sanctuaries
number-of-sanctuaries
0
10
1.0
1
1
NIL
HORIZONTAL

SLIDER
1760
398
1946
431
sanctuary-region-size
sanctuary-region-size
0
10
10.0
1
1
NIL
HORIZONTAL

MONITOR
557
14
742
59
Time of Drugboat Escaping
time-to-first-arrival
17
1
11

SLIDER
1761
502
1908
535
max_levy_time
max_levy_time
0
100
15.0
1
1
sec
HORIZONTAL

CHOOSER
25
148
223
193
selected_algorithm_hunters
selected_algorithm_hunters
"Milling" "Diffusing" "Lie and Wait" "Standard Random" "Straight" "Spiral" "Custom"
0

CHOOSER
1764
542
1950
587
distribution_for_direction
distribution_for_direction
"uniform" "gaussian" "triangle"
0

TEXTBOX
263
385
478
411
for random walk algorithms parameters
11
0.0
1

SLIDER
264
444
437
477
step_length_fixed
step_length_fixed
0
100
50.0
10
1
NIL
HORIZONTAL

TEXTBOX
26
66
214
89
Hunters
11
0.0
1

SLIDER
12
1230
231
1263
noise-actuating-speed
noise-actuating-speed
0
1
0.1
0.1
1
m/s
HORIZONTAL

SLIDER
10
1282
246
1315
noise-actuating-turning
noise-actuating-turning
0
30
20.0
5
1
deg/s
HORIZONTAL

SLIDER
10
1338
191
1371
state-disturbance_xy
state-disturbance_xy
0
1
0.0
0.1
1
NIL
HORIZONTAL

SLIDER
16
1390
217
1423
state-disturbance_head
state-disturbance_head
0
50
0.0
5
1
NIL
HORIZONTAL

SLIDER
1760
152
1937
185
number-of-drugboats
number-of-drugboats
0
1
1.0
1
1
NIL
HORIZONTAL

SLIDER
1760
190
1964
223
vision-distance-drugboats
vision-distance-drugboats
0
2
0.9
0.1
1
m
HORIZONTAL

SLIDER
1763
229
1988
262
vision-cone-drugboats
vision-cone-drugboats
0
360
360.0
10
1
deg
HORIZONTAL

SLIDER
1760
266
1954
299
speed-drugboats
speed-drugboats
0
0.25
0.23
0.05
1
m/s
HORIZONTAL

SLIDER
1759
306
2001
339
turning-rate-drugboats
turning-rate-drugboats
0
180
40.0
10
1
deg/s
HORIZONTAL

CHOOSER
256
236
464
281
selected_algorithm_drugboat
selected_algorithm_drugboat
"Auto" "Manual Control"
1

MONITOR
795
14
965
59
Time of Drugboat Caught
time-of-first-drugboat-detected
17
1
11

CHOOSER
23
86
221
131
Hunter_setup
Hunter_setup
"Random" "Inverted V" "Center Band" "Barrier" "Circle - Center" "Circle - Center - Facing Out" "Circle - Random" "Perfect Circle" "Perfect Picket" "Imperfect Picket" "Custom - Region" "Custom - Precise"
7

BUTTON
1159
157
1242
191
Forward
ask drugboats[ set inputs (list (speed-drugboats * 10) 90 0)]
NIL
1
T
OBSERVER
NIL
W
NIL
NIL
1

BUTTON
1159
204
1239
238
Reverse
ask drugboats[ set inputs (list (speed-drugboats * 10) 270 0)]
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
1256
203
1323
237
Right
ask drugboats[ set inputs (list (speed-drugboats * 10 * 0.833) 0 0)]
NIL
1
T
OBSERVER
NIL
D
NIL
NIL
1

BUTTON
1088
207
1152
241
Left
ask drugboats[ set inputs (list (speed-drugboats * 10 * 0.833) 180 0)]
NIL
1
T
OBSERVER
NIL
A
NIL
NIL
1

BUTTON
1256
158
1378
192
Diagonal Right
ask drugboats[ set inputs (list (speed-drugboats * 10 * 0.66) 45 0)]
NIL
1
T
OBSERVER
NIL
E
NIL
NIL
1

BUTTON
1038
158
1151
192
Diagonal Left
ask drugboats[ set inputs (list (speed-drugboats * 10 * 0.66) 135 0)]
NIL
1
T
OBSERVER
NIL
Q
NIL
NIL
1

BUTTON
1252
253
1399
287
Diagonal Right - Reverse
ask drugboats[ set inputs (list (speed-drugboats * 10 * 0.66) 315 0)]
NIL
1
T
OBSERVER
NIL
C
NIL
NIL
1

BUTTON
1008
249
1152
283
Diagonal Left - Reverse
ask drugboats[ set inputs (list (speed-drugboats * 10 * 0.66) 225 0)]
NIL
1
T
OBSERVER
NIL
Z
NIL
NIL
1

BUTTON
1169
254
1233
288
Stop
ask drugboats[ set inputs (list 0 0 0)]
NIL
1
T
OBSERVER
NIL
X
NIL
NIL
1

BUTTON
1208
293
1306
327
Turn Right
ask drugboats[ set inputs (list 0 90 30)]
NIL
1
T
OBSERVER
NIL
T
NIL
NIL
1

BUTTON
1101
293
1190
327
Turn Left
ask drugboats[ set inputs (list 0 90 -30)]
NIL
1
T
OBSERVER
NIL
R
NIL
NIL
1

SWITCH
258
198
423
231
protected_spawn?
protected_spawn?
1
1
-1000

SWITCH
299
30
418
63
loop_sim?
loop_sim?
1
1
-1000

SWITCH
16
245
234
278
can_hunters_see_each_other?
can_hunters_see_each_other?
0
1
-1000

TEXTBOX
1763
121
1978
147
Don't adjust these sliders!
11
0.0
1

TEXTBOX
1028
125
1406
144
Controls for 'selected_algorithm_drugboat' = Manual Control
11
0.0
1

SLIDER
263
405
437
438
turning-rate-rw
turning-rate-rw
0
180
180.0
10
1
deg/s
HORIZONTAL

SLIDER
286
312
458
345
blind_percentage
blind_percentage
0
100
30.0
10
1
NIL
HORIZONTAL

CHOOSER
15
198
218
243
selected_algorithm_hunters_blind
selected_algorithm_hunters_blind
"Milling" "Diffusing" "Diffusing2" "Lie and Wait" "Standard Random" "Straight" "Spiral" "Custom"
2

SWITCH
263
523
458
556
randomize_blindness?
randomize_blindness?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

blind-hunters
true
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 0 0 300
Polygon -1 true false 150 0 105 135 195 135 150 0
Polygon -1 false false 75 165 210 225 90 225 210 165 210 225 255 135 60 135 90 225

boat
true
0
Polygon -7500403 true true 150 0 120 15 105 30 90 105 90 165 90 195 90 240 105 270 105 270 120 285 150 300 180 285 210 270 210 255 210 240 210 210 210 165 210 105 195 30 180 15
Line -1 false 150 60 120 135
Line -1 false 150 60 180 135
Polygon -1 false false 150 60 120 135 180 135 150 60 150 165

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
true
0
Line -7500403 true 135 135 135 30
Circle -7500403 true true 0 0 300

circle 2
true
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 0 0 300
Polygon -1 true false 150 0 105 135 195 135 150 0

circle 3
true
0
Circle -16777216 true false 0 0 300
Circle -7500403 true true 0 0 300
Polygon -1 true false 150 0 105 135 195 135 150 0
Rectangle -1 true false 55 171 250 246

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

levy
true
0
Polygon -7500403 true true 150 15 120 0 75 60 60 135 15 180 15 210 120 195 90 255 105 285 120 300 150 270 180 300 195 285 210 255 180 195 285 210 285 180 240 135 225 60 180 0
Polygon -1 true false 120 60 120 165 135 165 135 60
Polygon -1 true false 135 150 180 150 180 165 135 165

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

ring
true
0
Circle -7500403 true true 0 0 300
Polygon -1 false false 150 0 135 150 165 150 150 0

runner
true
0
Circle -7500403 true true -3 -3 306
Rectangle -7500403 true true 45 45 255 255
Polygon -1 true false 150 0 105 135 195 135 150 0
Rectangle -1 true false 60 60 250 225

sanctuary
true
0
Line -7500403 true 135 135 135 30
Circle -7500403 true true 0 0 300

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 0 0 300 300

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 219 240 248 246 269 228 281 215 267 193 225
Polygon -10899396 true false 225 90 255 75 275 75 290 89 299 108 291 124 270 105 255 105 240 105
Polygon -10899396 true false 75 90 45 75 25 75 10 89 1 108 9 124 30 105 45 105 60 105
Polygon -10899396 true false 132 70 134 49 107 36 108 2 150 -13 192 3 192 37 169 50 172 72
Polygon -10899396 true false 85 219 60 248 54 269 72 281 85 267 107 225
Polygon -7500403 true true 75 30 225 30 270 75 270 195 255 240 180 300 135 300 45 240 30 195 30 75

turtle2
true
0
Polygon -10899396 true false 215 219 240 248 246 269 228 281 215 267 193 225
Polygon -10899396 true false 225 90 255 75 275 75 290 89 299 108 291 124 270 105 255 105 240 105
Polygon -10899396 true false 75 90 45 75 25 75 10 89 1 108 9 124 30 105 45 105 60 105
Polygon -10899396 true false 132 70 134 49 107 36 108 2 150 -13 192 3 192 37 169 50 172 72
Polygon -10899396 true false 85 219 60 248 54 269 72 281 85 267 107 225
Polygon -7500403 true true 75 30 225 30 270 75 270 195 255 240 180 300 135 300 45 240 30 195 30 75

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Comaparing_Algs" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50001"/>
    <exitCondition>end_flag &gt; 0</exitCondition>
    <metric>time-to-first-arrival</metric>
    <metric>time-of-first-runner-detected</metric>
    <enumeratedValueSet variable="selected_algorithm1">
      <value value="&quot;Stop&quot;"/>
      <value value="&quot;Standard Random&quot;"/>
      <value value="&quot;VNQ&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hunters">
      <value value="1"/>
      <value value="4"/>
      <value value="9"/>
      <value value="16"/>
      <value value="25"/>
      <value value="36"/>
      <value value="49"/>
      <value value="64"/>
      <value value="81"/>
      <value value="100"/>
      <value value="121"/>
      <value value="144"/>
      <value value="169"/>
      <value value="196"/>
      <value value="225"/>
      <value value="256"/>
      <value value="289"/>
      <value value="324"/>
      <value value="361"/>
      <value value="400"/>
      <value value="441"/>
      <value value="484"/>
      <value value="529"/>
      <value value="576"/>
      <value value="625"/>
      <value value="676"/>
      <value value="729"/>
      <value value="784"/>
      <value value="841"/>
      <value value="900"/>
      <value value="961"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-no" first="1" step="1" last="40"/>
  </experiment>
  <experiment name="Comaparing_Algs_Log_scale" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50001"/>
    <exitCondition>end_flag &gt; 0</exitCondition>
    <metric>time-to-first-arrival</metric>
    <metric>time-of-first-runner-detected</metric>
    <enumeratedValueSet variable="selected_algorithm1">
      <value value="&quot;Ambush&quot;"/>
      <value value="&quot;Straight&quot;"/>
      <value value="&quot;Levy&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="number-of-hunters">
      <value value="1"/>
      <value value="2"/>
      <value value="4"/>
      <value value="6"/>
      <value value="10"/>
      <value value="18"/>
      <value value="32"/>
      <value value="57"/>
      <value value="100"/>
      <value value="178"/>
      <value value="317"/>
      <value value="563"/>
      <value value="1000"/>
    </enumeratedValueSet>
    <steppedValueSet variable="seed-no" first="1" step="1" last="40"/>
  </experiment>
  <experiment name="Turbo_Pi" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="50001"/>
    <exitCondition>end_flag &gt; 0</exitCondition>
    <metric>time-to-first-arrival</metric>
    <metric>time-of-first-runner-detected</metric>
    <enumeratedValueSet variable="selected_algorithm1">
      <value value="&quot;Alg A&quot;"/>
      <value value="&quot;Alg B&quot;"/>
      <value value="&quot;Standard Random&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="number-of-hunters" first="5" step="5" last="150"/>
    <steppedValueSet variable="seed-no" first="1" step="1" last="40"/>
  </experiment>
  <experiment name="ECE101_scoring" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="25001"/>
    <exitCondition>end_flag &gt; 0</exitCondition>
    <metric>time-to-first-arrival</metric>
    <metric>time-of-first-drugboat-detected</metric>
    <steppedValueSet variable="seed-no" first="1" step="1" last="10"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@