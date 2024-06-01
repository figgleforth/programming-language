api Record

id: int

# when = nil, then the column is nillable
uuid: string = nil
created_at: Date_Time = nil
updated_at: Date_Time = nil
deleted_at: Date_Time = nil

def find(id: int) -> Record;

def where -> [Record];

def delete -> bool;

def destroy -> bool;
