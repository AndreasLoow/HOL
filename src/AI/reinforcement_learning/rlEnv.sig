signature rlEnv =
sig

  include Abbrev

  val rl_gencode_dir : string ref

  (* 'a is the type of board
     ''b is the type for move
     'c is the type of targets *)
  type ('a,''b,'c) gamespec =
    {
    movel : ''b list,
    string_of_move : ''b -> string,
    filter_sit : 'a psMCTS.sit -> ((''b * real) list -> (''b * real) list),
    status_of : ('a psMCTS.sit -> psMCTS.status),
    apply_move : (''b -> 'a psMCTS.sit -> 'a psMCTS.sit),
    operl : (term * int) list,
    nntm_of_sit: 'a psMCTS.sit -> term
    }

  (* rl parameters *)
  val ngen_glob : int ref
  val ntarget_compete : int ref    
  val ntarget_explore : int ref
  (* nn parameters *)
  val exwindow_glob : int ref
  val uniqex_flag : bool ref
  val dim_glob : int ref
  val batchsize_glob : int ref 
  val nepoch_glob : int ref
  val ncore_train_glob : int ref  
  (* mcts parameters *)
  val nsim_glob : int ref
  val decay_glob : real ref
  val ncore_mcts_glob : int ref

  (* adaptative difficulty *)
  val level_glob : int ref

  (* external calls *)
  val worker_start : bool * bool -> int -> unit
  val boss_start : int -> bool * bool ->
    mlTreeNeuralNetwork.dhtnn ->
    rlGameArithGround.board psMCTS.sit list ->
    int * (term * real list * real list) list list

  (* training *)
  val random_dhtnn_gamespec : 
    (rlGameArithGround.board, ''a, 'b) gamespec -> 
    mlTreeNeuralNetwork.dhtnn
  val random_example : term list -> int -> 
    (term * real list * real list)
  val train_dhtnn : 
    (rlGameArithGround.board, ''a, 'b) gamespec ->
    (term * real list * real list) list  ->
    mlTreeNeuralNetwork.dhtnn
  

  val logfile_glob : string ref
  val summary : string -> unit

  val start_rl_loop : 
    (rlGameArithGround.board, ''a, 'b) gamespec ->
    (term * real list * real list) list  *
    mlTreeNeuralNetwork.dhtnn *
    rlGameArithGround.board psMCTS.sit list


end
