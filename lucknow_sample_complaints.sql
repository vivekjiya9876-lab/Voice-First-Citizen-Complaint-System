-- Copy and run this in your Supabase SQL Editor to instantly generate sample complaints!

insert into public.complaints (
  text, 
  category, 
  status, 
  image_url, 
  latitude, 
  longitude, 
  upvotes
) values 
(
  'Huge pothole near Hazratganj crossing causing severe traffic jams. Needs immediate repair!',
  'Roads',
  'Pending',
  'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?q=80&w=2000&auto=format&fit=crop',
  26.8505,
  80.9399,
  24
),
(
  'Garbage piled up heavily outside Charbagh Railway Station. It is causing a major health hazard.',
  'Sanitation',
  'In Progress',
  'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?q=80&w=2000&auto=format&fit=crop',
  26.8329,
  80.9200,
  18
),
(
  'Street lights completely dead along Marine Drive, Gomti Nagar. Extremely dark and unsafe at night!',
  'Electricity',
  'Pending',
  'https://images.unsplash.com/photo-1517722014278-c256a91a6fba?q=80&w=2000&auto=format&fit=crop',
  26.8524,
  80.9996,
  42
);
